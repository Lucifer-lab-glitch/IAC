# -------------------- Linux Virtual Machine ------------------- #
resource "azurerm_linux_virtual_machine" "vm_linux" {
  count                           = var.create_linux_vm ? 1 : 0
  name                            = var.vm_name
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = var.location
  size                            = var.vm_size
  network_interface_ids           = [azurerm_network_interface.vm_nic[0].id]
  disable_password_authentication = var.disable_password_authentication
  admin_username                  = var.admin_username
  admin_password                  = random_password.admin_password[0].result

  # OS Disk Configuration
  os_disk {
    name                   = "${var.vm_name}-osdisk"
    caching                = "ReadWrite"
    storage_account_type   = var.disk_storage_account_type
    disk_size_gb           = var.os_disk_size
    disk_encryption_set_id = azurerm_disk_encryption_set.des.id
  }

  # Image Reference for Linux VM
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  # Cloud-Init Script for VM Configuration
  custom_data = base64encode(var.cloud_init_script)

  # Identity for VM
  # Identity Block
  identity {
    type         = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? var.identity_ids : null
  }
  tags = merge({ "ResourceName" = "LinuxVM" }, var.tags)
}

# -------------------- Log Analytics Agent for Linux VM ( Monitoring Purpose)------------------- #
resource "azurerm_virtual_machine_extension" "log_analytics_linux" {
  count                      = var.enable_monitoring ? 1 : 0
  name                       = "LogAnalyticsAgentLinux"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm_linux[0].id
  publisher                  = "Microsoft.Azure.MonitoringAgent"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.6"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "workspaceId": "${azurerm_log_analytics_workspace.log_workspace.workspace_id}"
        }
  SETTINGS

  protected_settings = <<PROTECTED
    {
      "workspaceKey": "${var.log_analytics_workspace_key}"
    }
  PROTECTED
}

# -------------------- Data Disk Attachment ------------------- #
resource "azurerm_virtual_machine_data_disk_attachment" "this_linux" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if lower(values.os_type) == "linux" }

  managed_disk_id           = azurerm_managed_disk.disk[each.key].id
  virtual_machine_id        = azurerm_linux_virtual_machine.vm_linux[0].id
  lun                       = each.value.lun
  caching                   = each.value.caching
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}
