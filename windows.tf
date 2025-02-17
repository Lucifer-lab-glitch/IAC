# -------------------- Windows Virtual Machine ------------------- #
resource "azurerm_windows_virtual_machine" "vm_windows" {
  count                   = var.create_windows_vm ? 1 : 0
  name                    = var.vm_name
  resource_group_name     = azurerm_resource_group.rg.name
  location                = var.location
  size                    = var.vm_size
  network_interface_ids   = [azurerm_network_interface.vm_nic[0].id]
  admin_username          = var.admin_username
  admin_password          = random_password.admin_password[0].result



  #------ OS Disk Configuration----------
  os_disk {
    name                   = "${var.vm_name}-osdisk"
    caching                = "ReadWrite"
    storage_account_type   = var.disk_storage_account_type
    disk_size_gb           = var.os_disk_size
    disk_encryption_set_id = azurerm_disk_encryption_set.des.id
  }

  # Enable Automatic Updates-------( enabling automatic updates is not available as a built-in option in the Linux)
  enable_automatic_updates = true  # Recommended for patch management and security updates

  # Image Reference for Windows VM
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

 # Boot Diagnostics (Capture serial console output and screenshots of the virtual machine.Stored in an Azure Storage Account)
  boot_diagnostics {
    storage_account_uri = var.boot_diagnostics_storage_account_uri
  }

  # Identity for VM
  
  # Identity Block
  identity {
    type        = var.identity_type
    identity_ids = var.identity_type == "UserAssigned" ? var.identity_ids : null
  }
    tags = merge({ "ResourceName" = "WindowsVM" }, var.tags)
}

# -------------------- Data Disk Attachment for Windows VM ------------------- #
resource "azurerm_virtual_machine_data_disk_attachment" "this_windows" {
  for_each = { for disk, values in var.data_disk_managed_disks : disk => values if lower(values.os_type) == "windows" }

  caching                   = each.value.caching
  lun                       = each.value.lun
  managed_disk_id           = azurerm_managed_disk.disk[each.key].id
  virtual_machine_id        = azurerm_windows_virtual_machine.vm_windows[0].id
  create_option             = each.value.disk_attachment_create_option
  write_accelerator_enabled = each.value.write_accelerator_enabled
}

# -------------------- Log Analytics Agent for Windows VM ( Monitoring Purpose) ------------------- #
resource "azurerm_virtual_machine_extension" "log_analytics_windows" {
  count                = var.enable_monitoring ? 1 : 0
  name                 = "LogAnalyticsAgentWindows"
  virtual_machine_id   = azurerm_windows_virtual_machine.vm_windows[0].id
  publisher            = "Microsoft.Azure.MonitoringAgent"
  type                 = "AzureMonitorWindowsAgent"
  type_handler_version = "1.6.2"
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
