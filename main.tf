#Author Kushal Kumar (BD/DPA CS03)


data "azurerm_client_config" "current" {}
# -------------------- Provider Configuration -------------------
provider "azurerm" {
  features {}

  subscription_id = "87c9cdc0-75e2-4e53-b528-673f2cedc16f"
  tenant_id       = "1bbb07e3-9747-427c-9b99-3b24eb1b3ae5"
}

# -------------------- Resource Group -------------------
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# -------------------- Virtual Network -------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.vm_name}-vnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space

  tags = var.tags
}

# -------------------- Subnet -------------------
resource "azurerm_subnet" "sub" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_address_prefixes
}


# -------------------- Create Public IP ------------------- #

resource "azurerm_public_ip" "pubip" {
  count               = var.enable_public_ip ? 1 : 0
  name                = "${var.vm_name}-public-ip"
  location            = var.location
  resource_group_name = var.resource_group_name.rg.name
  allocation_method   = var.public_ip_sku =="Standard" ? "Static"  : var.allocation_method  # Options: "Static" or "Dynamic"
  sku                 = var.public_ip_sku  # Recommended: "Standard" for production workloads

  tags = merge({ "ResourceName" = "PubIP" }, var.tags,)
}


# -------------------- Network Interface -------------------
resource "azurerm_network_interface" "vm_nic" {
  count                         = var.resource_count
  name                          = "${var.vm_name}-nic"
  location                      = var.location
  resource_group_name           = azurerm_resource_group.rg.name
  accelerated_networking_enabled = true  #Improve VM network performance for applications with high network demands.
  ip_configuration {
    name                          = "internalIP-vm-${format("%02d", count.index + 1)}"
    subnet_id                     = var.subnet
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = coalesce(var.public_ip_id, azurerm_public_ip.pubip[0].id)


  }
}


# -------------------- Key Vault -------------------

resource "random_id" "keyvault_suffix" {
  byte_length = 4
}

resource "azurerm_key_vault" "mainkey" {
  name                = "${var.vm_name}-secure-keyvault-${random_id.keyvault_suffix.hex}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled = true

  tags = var.tags
}


#-------------------- Create Encryption Key in Key Vault ------------------- #
resource "azurerm_key_vault_key" "disk_encryption_key" {
  name         = "disk-encryption-key"
  key_vault_id = azurerm_key_vault.mainkey.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts     = ["encrypt", "decrypt", "wrapKey", "unwrapKey"]
}

# -------------------- Key Vault Access Policy for Linux VM and Windows VM -------------------
resource "azurerm_key_vault_access_policy" "des_access" {
  for_each = {
    linux_vm   = azurerm_linux_virtual_machine.vm_linux[0].identity[0].principal_id
    windows_vm = azurerm_windows_virtual_machine.vm_windows[0].identity[0].principal_id
  }

  key_vault_id = azurerm_key_vault.mainkey.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions = ["Get", "List"]
  key_permissions    = ["Get", "List", "UnwrapKey", "WrapKey"]
}



# -------------------- Disk Resources -------------------

resource "azurerm_disk_encryption_set" "des" {
  name                = "${var.vm_name}-des"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  key_vault_key_id    = azurerm_key_vault_key.disk_encryption_key.id
  identity {
    type = "SystemAssigned"
  }
}


resource "azurerm_managed_disk" "disk" {
  for_each = var.data_disk_managed_disks

  create_option                     = each.value.create_option
  location                          = var.location
  name                              = each.value.name
  resource_group_name               = var.resource_group_name
  storage_account_type              = each.value.storage_account_type
  disk_size_gb                      = each.value.disk_size_gb
  zone                              = var.zone
  disk_encryption_set_id = azurerm_disk_encryption_set.des.id
}



# -------------------- Admin Password Generation ------------------- #
resource "random_password" "admin_password" {
  count  = 1  # Always create a password
  length = 8
  special = true
  override_special = "!#$%&()*+,-./:;<=>?@[]^_{|}~"
}

# -------------------- Store Admin Password in Key Vault ------------------- #
resource "azurerm_key_vault_secret" "admin_password" {
  count = (
    (var.generate_admin_password_or_ssh_key == true && lower(var.os_type) == "windows" && (var.generated_secrets_key_vault_secret_config != null || var.admin_credential_key_vault_resource_id != null)) ||
    (var.generate_admin_password_or_ssh_key == true && lower(var.os_type) == "linux" && var.disable_password_authentication == false && (var.generated_secrets_key_vault_secret_config != null || var.admin_credential_key_vault_resource_id != null))
  ) ? 1 : 0

  key_vault_id    = coalesce(var.admin_credential_key_vault_resource_id, var.generated_secrets_key_vault_secret_config.key_vault_resource_id)
  name            = coalesce(
    var.admin_password_key_vault_secret_name, 
    var.generated_secrets_key_vault_secret_config.name, 
    local.generated_admin_password_secret_name
  )
  value           = random_password.admin_password[0].result
  content_type    = var.generated_secrets_key_vault_secret_config.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  #not_before_date = var.generated_secrets_key_vault_secret_config.not_before_date
  tags            = var.generated_secrets_key_vault_secret_config.tags != {} ? var.generated_secrets_key_vault_secret_config.tags : var.tags

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# -------------------- SSH Key Generation ------------------- #
resource "tls_private_key" "ssh_key" {
  count    = var.generate_admin_ssh_key ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# -------------------- Store SSH Key in Key Vault ------------------- #
resource "azurerm_key_vault_secret" "admin_ssh_key" {
  count = ((var.generate_admin_password_or_ssh_key == true) && (lower(var.os_type) == "linux") && (var.disable_password_authentication == true) && (var.generated_secrets_key_vault_secret_config != null || var.admin_credential_key_vault_resource_id != null)) ? 1 : 0

  key_vault_id    = coalesce(var.admin_credential_key_vault_resource_id, var.generated_secrets_key_vault_secret_config.key_vault_resource_id)
  name            = coalesce(var.admin_generated_ssh_key_vault_secret_name, var.generated_secrets_key_vault_secret_config.name, "${var.vm_name}-${var.admin_username}-ssh-private-key")
  value           = tls_private_key.ssh_key[0].private_key_pem
  content_type    = var.generated_secrets_key_vault_secret_config.content_type
  expiration_date = local.generated_secret_expiration_date_utc
  not_before_date = var.generated_secrets_key_vault_secret_config.not_before_date
  tags            = var.generated_secrets_key_vault_secret_config.tags != {} ? var.generated_secrets_key_vault_secret_config.tags : var.tags

  lifecycle {
    ignore_changes = [expiration_date]
  }
}

# --------------------Auto-Shutdown Schedule -------------------resource "azurerm_dev_test_global_vm_shutdown_schedule" "this"
resource "azurerm_dev_test_global_vm_shutdown_schedule" "this" {
  for_each = { for k, v in local.virtual_machine_info : k => v if v != null }

  virtual_machine_id       = each.value
  daily_recurrence_time    = var.shutdown_schedules[each.key].daily_recurrence_time
  location                 = var.location
  timezone                 = var.shutdown_schedules[each.key].timezone
  enabled                  = var.shutdown_schedules[each.key].enabled

  notification_settings {
    enabled         = var.shutdown_schedules[each.key].notification_settings.enabled
    email           = var.shutdown_schedules[each.key].notification_settings.email
    time_in_minutes = var.shutdown_schedules[each.key].notification_settings.time_in_minutes
    webhook_url     = var.shutdown_schedules[each.key].notification_settings.webhook_url
  }
}


# -------------------- Log Analytics Workspace -------------------
resource "azurerm_log_analytics_workspace" "log_workspace" {
  name                = "${var.vm_name}-log-ws"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

# -------------------- Dynamic Role Assignments-------------------Why Because For Contributor access automation...if not present means manually we have to give every time roles

# Loop through the role assignments and create each one dynamically
resource "azurerm_role_assignment" "dynamic_roles" {
  for_each            = var.role_assignments
  principal_id        = azuread_service_principal.terraform_sp.object_id  # Replace with your Service Principal or User Object ID
  role_definition_name = each.value.role_definition_name
  scope               = each.value.scope
}
