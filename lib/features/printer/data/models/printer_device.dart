/// A Bluetooth device candidate for thermal printing.
///
/// On Android this represents a paired Classic BT device (SPP).
/// On iOS this represents a scanned BLE peripheral.
class PrinterDevice {
  final String name;
  final String address; // MAC address on Android, UUID string on iOS

  const PrinterDevice({required this.name, required this.address});

  @override
  bool operator ==(Object other) =>
      other is PrinterDevice && other.address == address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'PrinterDevice(name: $name, address: $address)';
}
