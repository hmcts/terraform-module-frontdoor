provider "azurerm" {
  features {}
  subscription_id = "b72ab7b7-723f-4b18-b6f6-03b0f2c6a1bb"
}

provider "azurerm" {
  features {}
  alias           = "mgmt"
  subscription_id = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
}
