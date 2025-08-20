class InvoiceCounter {
  final String dateKey; // Format: YYYYMMDD
  int counter;

  InvoiceCounter({required this.dateKey, this.counter = 0});

  factory InvoiceCounter.fromMap(Map<dynamic, dynamic> map) {
    return InvoiceCounter(
      dateKey: map['dateKey'] as String,
      counter: map['counter'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateKey': dateKey,
      'counter': counter,
    };
  }
}