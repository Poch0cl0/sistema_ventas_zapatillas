import 'package:flutter_riverpod/flutter_riverpod.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.priceCents,
    required this.image,
    this.description =
        'Diseño urbano, comodidad para cada paso y una silueta que va contigo.',
    this.active = true,
  });
  final String id, name, brand, category, image, description;
  final int priceCents;
  final bool active;
  Product copyWith({
    String? name,
    String? brand,
    String? category,
    int? priceCents,
    String? description,
    bool? active,
  }) => Product(
    id: id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    category: category ?? this.category,
    priceCents: priceCents ?? this.priceCents,
    image: image,
    description: description ?? this.description,
    active: active ?? this.active,
  );
}

const sampleProducts = [
  Product(
    id: 'air-volt',
    name: 'Air Volt React GT',
    brand: 'Nike',
    category: 'Running',
    priceCents: 52900,
    image: 'assets/images/sneaker_1.png',
  ),
  Product(
    id: 'retro',
    name: 'Retro Street OG',
    brand: 'Jordan',
    category: 'Urbano',
    priceCents: 64900,
    image: 'assets/images/sneaker_2.png',
  ),
  Product(
    id: 'forum',
    name: 'Forum Low Urban',
    brand: 'Adidas',
    category: 'Urbano',
    priceCents: 38900,
    image: 'assets/images/sneaker_3.png',
  ),
  Product(
    id: '9060',
    name: '9060 Triple Sea',
    brand: 'New Balance',
    category: 'Urbano',
    priceCents: 57900,
    image: 'assets/images/sneaker_4.png',
  ),
];

class Products extends Notifier<List<Product>> {
  @override
  List<Product> build() => sampleProducts;
  void save(Product product) =>
      state = [...state.where((p) => p.id != product.id), product];
}

final productsProvider = NotifierProvider<Products, List<Product>>(
  Products.new,
);

class CartLine {
  const CartLine(this.product, this.size, this.quantity);
  final Product product;
  final String size;
  final int quantity;
  String get key => '${product.id}-$size';
  int get total => product.priceCents * quantity;
}

class Cart extends Notifier<List<CartLine>> {
  @override
  List<CartLine> build() => [];
  void add(Product product, String size, int quantity) {
    final key = '${product.id}-$size';
    final old = state.where((line) => line.key == key).firstOrNull;
    state = [
      ...state.where((line) => line.key != key),
      CartLine(product, size, ((old?.quantity ?? 0) + quantity).clamp(1, 9)),
    ];
  }

  void quantity(String key, int quantity) => state = [
    for (final line in state)
      if (line.key != key)
        line
      else if (quantity > 0)
        CartLine(line.product, line.size, quantity.clamp(1, 9)),
  ];
  void clear() => state = [];
}

final cartProvider = NotifierProvider<Cart, List<CartLine>>(Cart.new);

class DeliveryZone {
  const DeliveryZone(this.id, this.name, this.feeCents, {this.active = true});
  final String id, name;
  final int feeCents;
  final bool active;
}

class Zones extends Notifier<List<DeliveryZone>> {
  @override
  List<DeliveryZone> build() => const [
    DeliveryZone('miraflores', 'Miraflores', 1000),
    DeliveryZone('surco', 'Santiago de Surco', 1500),
    DeliveryZone('san-isidro', 'San Isidro', 1200),
  ];
  void save(DeliveryZone zone) =>
      state = [...state.where((z) => z.id != zone.id), zone];
}

final zonesProvider = NotifierProvider<Zones, List<DeliveryZone>>(Zones.new);

enum PaymentState { pending, review, approved, rejected }

enum OrderStage { pending, preparing, ready, delivered, cancelled }

class PreviewOrder {
  const PreviewOrder({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.expiresAt,
    this.delivery = false,
    this.zone = '',
    this.address = '',
    this.recipient = 'Cliente de ejemplo',
    this.phone = '',
    this.deliveryReference = '',
    this.feeCents = 0,
    this.payment = PaymentState.pending,
    this.stage = OrderStage.pending,
    this.method = '',
    this.reference = '',
    this.rejection = '',
  });
  final String id,
      zone,
      address,
      recipient,
      phone,
      deliveryReference,
      method,
      reference,
      rejection;
  final List<CartLine> items;
  final DateTime createdAt, expiresAt;
  final bool delivery;
  final int feeCents;
  final PaymentState payment;
  final OrderStage stage;
  int get subtotal => items.fold(0, (sum, line) => sum + line.total);
  int get total => subtotal + feeCents;
  bool get expired => DateTime.now().isAfter(expiresAt);
  bool get canPay =>
      !expired &&
      stage != OrderStage.cancelled &&
      (payment == PaymentState.pending || payment == PaymentState.rejected);
  PreviewOrder copyWith({
    PaymentState? payment,
    OrderStage? stage,
    String? method,
    String? reference,
    String? rejection,
  }) => PreviewOrder(
    id: id,
    items: items,
    createdAt: createdAt,
    expiresAt: expiresAt,
    delivery: delivery,
    zone: zone,
    address: address,
    recipient: recipient,
    phone: phone,
    deliveryReference: deliveryReference,
    feeCents: feeCents,
    payment: payment ?? this.payment,
    stage: stage ?? this.stage,
    method: method ?? this.method,
    reference: reference ?? this.reference,
    rejection: rejection ?? this.rejection,
  );
}

class Orders extends Notifier<List<PreviewOrder>> {
  @override
  List<PreviewOrder> build() {
    final now = DateTime.now();
    return [
      PreviewOrder(
        id: 'SK-84920',
        items: [CartLine(sampleProducts[0], '41', 1)],
        createdAt: now.subtract(const Duration(hours: 2)),
        expiresAt: now.add(const Duration(hours: 22)),
        payment: PaymentState.review,
        method: 'YAPE',
        reference: 'DEMO-84920',
      ),
      PreviewOrder(
        id: 'SK-83105',
        items: [CartLine(sampleProducts[2], '39', 1)],
        createdAt: now.subtract(const Duration(days: 3)),
        expiresAt: now.subtract(const Duration(days: 2)),
        payment: PaymentState.approved,
        stage: OrderStage.delivered,
      ),
    ];
  }

  void save(PreviewOrder order) =>
      state = [order, ...state.where((o) => o.id != order.id)];
}

final ordersProvider = NotifierProvider<Orders, List<PreviewOrder>>(Orders.new);
String paymentLabel(PaymentState state) => switch (state) {
  PaymentState.pending => 'Pendiente de pago',
  PaymentState.review => 'Pago en revisión',
  PaymentState.approved => 'Pago aprobado',
  PaymentState.rejected => 'Pago rechazado',
};
String stageLabel(OrderStage state, {bool delivery = false}) => switch (state) {
  OrderStage.pending => 'Por confirmar',
  OrderStage.preparing => 'Preparando',
  OrderStage.ready => delivery ? 'En reparto' : 'Listo para recojo',
  OrderStage.delivered => 'Entregado',
  OrderStage.cancelled => 'Cancelado',
};

class PreviewProfile {
  const PreviewProfile(this.name, this.phone);
  final String name, phone;
}

class Profile extends Notifier<PreviewProfile> {
  @override
  PreviewProfile build() =>
      const PreviewProfile('Cliente de ejemplo', '999 000 111');
  void save(String name, String phone) => state = PreviewProfile(name, phone);
}

final profileProvider = NotifierProvider<Profile, PreviewProfile>(Profile.new);

class Inventory extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {
    for (final p in sampleProducts)
      for (final size in ['38', '39', '40', '41', '42', '43'])
        '${p.id}-$size': size == '38'
            ? 0
            : size == '41'
            ? 1
            : 5,
  };
  int available(String product, String size) => state['$product-$size'] ?? 0;
  void adjust(String product, String size, int amount) =>
      state = {...state, '$product-$size': amount};
}

final inventoryProvider = NotifierProvider<Inventory, Map<String, int>>(
  Inventory.new,
);
