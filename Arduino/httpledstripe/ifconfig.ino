
#if defined(BOARD_ARDUINO)

#define NET_EEPROM_OFFSET 0
#define NET_EEPROM_MAGIC 0x55

#define GW_OFFSET (NET_EEPROM_OFFSET + 3)
#define SUBNET_OFFSET (GW_OFFSET + 4)
#define MAC_OFFSET (SUBNET_OFFSET + 4)
#define IP_OFFSET (MAC_OFFSET + 6)
#define APP_OFFSET (IP_OFFSET + 4)

void ifconfig_begin() {
  delay(250); // For ethernet instantiation
  if (ifconfig_checkMagic()) {
    byte mac[6];
    byte ip[4];
    byte dns[4];
    byte gw[4];
    byte subnet[4];

    ifconfig_readEEPROM(F("MAC: "),mac,MAC_OFFSET,6);
    ifconfig_readEEPROM(F("IP:  "),ip,IP_OFFSET,4);
    ifconfig_readEEPROM(F("DNS: "),dns,GW_OFFSET,4);
    ifconfig_readEEPROM(F("GW:  "),gw,GW_OFFSET,4);
    ifconfig_readEEPROM(F("SNM: "),subnet,SUBNET_OFFSET,4);

    Ethernet.begin(mac, ip, dns, gw, subnet);
  } else {
    Serial.println("Invalid network configuration in EEPROM");
  }
}

void ifconfig_readEEPROM(String msg, byte data[], int offset, int length) {
  Serial.print(msg);
  for (int i = 0; i < length; i++) {
    byte b = EEPROM.read(offset + i);
    data[i] = b;
    Serial.print(b);
    Serial.print(',');
  }
  Serial.println();
}

int ifconfig_checkMagic() {
  return EEPROM.read(NET_EEPROM_OFFSET) == NET_EEPROM_MAGIC;
}

#endif
