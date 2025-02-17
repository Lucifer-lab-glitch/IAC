locals {
  # Mapping for Key Vault access policy principal IDs
  key_vault_access_policy_principals = {
    linux_vm   = azurerm_linux_virtual_machine.vm_linux[0].identity[0].principal_id
    windows_vm = azurerm_windows_virtual_machine.vm_windows[0].identity[0].principal_id
  }

  # Mapping for virtual machine information (use apply-time known IDs)
   virtual_machine_info = {
    linux_vm  = try(azurerm_linux_virtual_machine.vm_linux[0].id, null)
    windows_vm = try(azurerm_windows_virtual_machine.vm_windows[0].id, null)
  }

  # Expiration date set to 30 days from now
  generated_secret_expiration_date_utc = timeadd(timestamp(), "720h")  # 720 hours = 30 days

  # Admin password secret name format
  generated_admin_password_secret_name = "${var.vm_name}-${var.admin_username}-password"
}
