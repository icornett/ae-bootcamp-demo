# Import only resources that are confirmed to already exist in Azure.
# These blocks are safe to keep temporarily until the first successful apply.

import {
  to = azurerm_resource_group.main
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog"
}

import {
  to = azurerm_key_vault.main
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog/providers/Microsoft.KeyVault/vaults/workout-kv-37081a3e"
}

import {
  to = azurerm_postgresql_flexible_server.main
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog/providers/Microsoft.DBforPostgreSQL/flexibleServers/workout-pg-37081a3e"
}

import {
  to = azurerm_postgresql_flexible_server_firewall_rule.azure_services
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog/providers/Microsoft.DBforPostgreSQL/flexibleServers/workout-pg-37081a3e/firewallRules/allow-azure-services"
}

import {
  to = azurerm_postgresql_flexible_server_database.training_log
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog/providers/Microsoft.DBforPostgreSQL/flexibleServers/workout-pg-37081a3e/databases/training_log"
}

import {
  to = azurerm_storage_account.caddy
  id = "/subscriptions/37081a3e-42d1-4416-ab97-18f723c2c292/resourceGroups/icornett-ae-workout-blog/providers/Microsoft.Storage/storageAccounts/workoutcaddy37081a3e"
}

import {
  to = azurerm_storage_share.caddy_data
  id = "https://workoutcaddy37081a3e.file.core.windows.net/caddy-data"
}

import {
  to = azurerm_key_vault_secret.database_url
  id = "https://workout-kv-37081a3e.vault.azure.net/secrets/database-url/9a25d61597714998ada4a7be1a2cd90e"
}

import {
  to = azurerm_key_vault_secret.pg_password
  id = "https://workout-kv-37081a3e.vault.azure.net/secrets/pg-admin-password/fd638a282f984a8cbeb3333f5feb8209"
}
