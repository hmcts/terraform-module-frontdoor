locals {
  dns_zone_subscription = "ed302caf-ec27-4c64-a05e-85731c3ce90e"
  cache                 = lookup(each.value, "cache_enabled", "true") == "true" ? true : false
}
