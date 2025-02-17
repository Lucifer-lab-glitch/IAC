
output "linux_vm_id" {
  description = "ID of the Linux VM"
  value       = azurerm_linux_virtual_machine.vm_linux[0].id
}

output "windows_vm_id" {
  description = "ID of the Windows VM"
  value       = azurerm_windows_virtual_machine.vm_windows[0].id
}


output "public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.pubip[0].ip_address
}


output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.log_workspace.id
}
