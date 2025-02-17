# Admin credentials
admin_password = "YourSecurePassword"
admin_username = "adminuser"

# VM and resource configurations
location            = "East US"
resource_group_name = "rg"
vm_name             = "my-vm"
vm_size             = "Standard_B2s"
subnet              = "/subscriptions/xxxx/resourceGroups/rg-name/providers/Microsoft.Network/virtualNetworks/vnet-name/subnets/subnet-name"
os_type             = "linux"

# Log Analytics Workspace key
log_analytics_workspace_key = "your-log-analytics-primary-key"

# Identity configuration
identity_type = "SystemAssigned"
identity_ids  = []

# Public IP configuration
enable_public_ip = true
public_ip_id     = ""

# Cloud-init script (Linux VM)
cloud_init_script = <<EOT
#!/bin/bash
# Update packages and install nginx
apt-get update -y
apt-get install nginx -y
systemctl enable nginx
systemctl start nginx
EOT

# Data Disk Managed Disks Configuration
data_disk_managed_disks = {
  disk1 = {
    name                                 = "datadisk1"
    create_option                        = "Empty"
    disk_size_gb                         = 100
    storage_account_type                 = "Standard_LRS"
    disk_encryption_key_vault_secret_url = null
    key_encryption_key_vault_secret_url  = null
    lun                                  = 0
    write_accelerator_enabled            = false
    lock_level                           = "None"
    lock_name                            = "disk1-lock"
    os_type                              = "linux"
    caching                              = "None"
    disk_attachment_create_option        = "Attach"
  }
}

# Virtual Network and Subnet
vnet_address_space      = ["10.0.0.0/16"]
subnet_address_prefixes = ["10.0.1.0/24"]

# Auto - Shutdown Schedules
shutdown_schedules = {
  linux_vm = {
    daily_recurrence_time = "1700"
    timezone              = "Pacific Standard Time"
    enabled               = true
    notification_settings = {
      enabled         = true
      email           = "linux@example.com"
      time_in_minutes = "15"
      webhook_url     = "https://linux-webhook-url.com"
    }
  }
  windows_vm = {
    daily_recurrence_time = "1800"
    timezone              = "Eastern Standard Time"
    enabled               = true
    notification_settings = {
      enabled         = true
      email           = "windows@example.com"
      time_in_minutes = "15"
      webhook_url     = "https://windows-webhook-url.com"
    }
  }
}


# Image Reference
image_publisher = "Canonical"
image_offer     = "UbuntuServer"
image_sku       = "18.04-LTS"
image_version   = "latest"

# Boot Diagnostics
boot_diagnostics_storage_account_uri = "https://yourstorageaccount.blob.core.windows.net/"


# -------------------- Dynamic Role Assignments-------------------
role_assignments = {
  "network_contributor" = {
    role_definition_name = "Network Contributor"
    scope               = "/subscriptions/87c9cdc0-75e2-4e53-b528-673f2cedc16f/resourceGroups/rg/providers/Microsoft.Network/virtualNetworks/my-vm-vnet/subnets/my-vm-subnet"
  }
  "storage_blob_data_contributor" = {
    role_definition_name = "Storage Blob Data Contributor"
    scope               = "/subscriptions/87c9cdc0-75e2-4e53-b528-673f2cedc16f/resourceGroups/rg/providers/Microsoft.Storage/storageAccounts/my-storage-account"
  }
}
