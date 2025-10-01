import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Dart implementation of Stripe SDK
/// Converted from TypeScript Stripe SDK
class Stripe {
  final String _apiKey;
  final String _baseUrl = 'https://api.stripe.com/v1';

  Stripe(this._apiKey);

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_apiKey',
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  /// Create a payment intent
  Future<PaymentIntent> createPaymentIntent(CreatePaymentIntentRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/payment_intents'),
      headers: _headers,
      body: _encodeRequest({
        'amount': request.amount,
        'currency': request.currency,
        'payment_method_types': json.encode(request.paymentMethodTypes),
        'metadata': request.metadata,
        'description': request.description,
      }),
    );

    if (response.statusCode == 200) {
      return PaymentIntent.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  /// Retrieve a payment intent
  Future<PaymentIntent> retrievePaymentIntent(String paymentIntentId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/payment_intents/$paymentIntentId'),
      headers: _headers,
    );

    if (response.statusCode == 200) {
      return PaymentIntent.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  /// Confirm a payment intent
  Future<PaymentIntent> confirmPaymentIntent(String paymentIntentId, {
    String? paymentMethodId,
    Map<String, dynamic>? paymentMethodData,
  }) async {
    final body = <String, dynamic>{};

    if (paymentMethodId != null) {
      body['payment_method'] = paymentMethodId;
    }

    if (paymentMethodData != null) {
      body['payment_method_data'] = paymentMethodData;
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/payment_intents/$paymentIntentId/confirm'),
      headers: _headers,
      body: _encodeRequest(body),
    );

    if (response.statusCode == 200) {
      return PaymentIntent.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  /// Create a customer
  Future<Customer> createCustomer(CreateCustomerRequest request) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/customers'),
      headers: _headers,
      body: _encodeRequest({
        'email': request.email,
        'name': request.name,
        'phone': request.phone,
        'metadata': request.metadata,
      }),
    );

    if (response.statusCode == 200) {
      return Customer.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  /// List customers
  Future<CustomerList> listCustomers({int? limit, String? startingAfter}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (startingAfter != null) queryParams['starting_after'] = startingAfter;

    final uri = Uri.parse('$_baseUrl/customers').replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      return CustomerList.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  /// Create a setup intent for saving payment methods
  Future<SetupIntent> createSetupIntent({List<String>? paymentMethodTypes}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/setup_intents'),
      headers: _headers,
      body: _encodeRequest({
        'payment_method_types': json.encode(paymentMethodTypes ?? ['card']),
      }),
    );

    if (response.statusCode == 200) {
      return SetupIntent.fromJson(json.decode(response.body));
    } else {
      throw StripeException.fromJson(json.decode(response.body));
    }
  }

  String _encodeRequest(Map<String, dynamic> data) {
    return data.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value.toString())}')
        .join('&');
  }
}

/// Request classes (equivalent to TypeScript interfaces)
class CreatePaymentIntentRequest {
  final int amount;
  final String currency;
  final List<String> paymentMethodTypes;
  final Map<String, String>? metadata;
  final String? description;

  CreatePaymentIntentRequest({
    required this.amount,
    required this.currency,
    required this.paymentMethodTypes,
    this.metadata,
    this.description,
  });
}

class CreateCustomerRequest {
  final String? email;
  final String? name;
  final String? phone;
  final Map<String, String>? metadata;

  CreateCustomerRequest({
    this.email,
    this.name,
    this.phone,
    this.metadata,
  });
}

/// Response classes (equivalent to TypeScript interfaces)
class PaymentIntent {
  final String id;
  final String object;
  final int amount;
  final String currency;
  final String status;
  final String? clientSecret;
  final Map<String, dynamic>? metadata;
  final DateTime created;

  PaymentIntent({
    required this.id,
    required this.object,
    required this.amount,
    required this.currency,
    required this.status,
    this.clientSecret,
    this.metadata,
    required this.created,
  });

  factory PaymentIntent.fromJson(Map<String, dynamic> json) => PaymentIntent(
    id: json['id'],
    object: json['object'],
    amount: json['amount'],
    currency: json['currency'],
    status: json['status'],
    clientSecret: json['client_secret'],
    metadata: json['metadata'],
    created: DateTime.fromMillisecondsSinceEpoch(json['created'] * 1000),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'object': object,
    'amount': amount,
    'currency': currency,
    'status': status,
    'client_secret': clientSecret,
    'metadata': metadata,
    'created': created.millisecondsSinceEpoch ~/ 1000,
  };
}

class Customer {
  final String id;
  final String object;
  final String? email;
  final String? name;
  final String? phone;
  final Map<String, dynamic>? metadata;
  final DateTime created;

  Customer({
    required this.id,
    required this.object,
    this.email,
    this.name,
    this.phone,
    this.metadata,
    required this.created,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
    id: json['id'],
    object: json['object'],
    email: json['email'],
    name: json['name'],
    phone: json['phone'],
    metadata: json['metadata'],
    created: DateTime.fromMillisecondsSinceEpoch(json['created'] * 1000),
  );
}

class CustomerList {
  final String object;
  final List<Customer> data;
  final bool hasMore;
  final String? url;

  CustomerList({
    required this.object,
    required this.data,
    required this.hasMore,
    this.url,
  });

  factory CustomerList.fromJson(Map<String, dynamic> json) => CustomerList(
    object: json['object'],
    data: (json['data'] as List).map((item) => Customer.fromJson(item)).toList(),
    hasMore: json['has_more'],
    url: json['url'],
  );
}

class SetupIntent {
  final String id;
  final String object;
  final String status;
  final String? clientSecret;
  final Map<String, dynamic>? metadata;
  final DateTime created;

  SetupIntent({
    required this.id,
    required this.object,
    required this.status,
    this.clientSecret,
    this.metadata,
    required this.created,
  });

  factory SetupIntent.fromJson(Map<String, dynamic> json) => SetupIntent(
    id: json['id'],
    object: json['object'],
    status: json['status'],
    clientSecret: json['client_secret'],
    metadata: json['metadata'],
    created: DateTime.fromMillisecondsSinceEpoch(json['created'] * 1000),
  );
}

class StripeException implements Exception {
  final String type;
  final String message;
  final String? code;
  final Map<String, dynamic>? param;

  StripeException({
    required this.type,
    required this.message,
    this.code,
    this.param,
  });

  factory StripeException.fromJson(Map<String, dynamic> json) => StripeException(
    type: json['error']['type'] ?? 'unknown_error',
    message: json['error']['message'] ?? 'Unknown error',
    code: json['error']['code'],
    param: json['error']['param'],
  );

  @override
  String toString() => 'StripeException: $type - $message';
}

/// Usage example (equivalent to TypeScript usage)
void exampleUsage() async {
  // Initialize Stripe (equivalent to: const stripe = new Stripe(process.env.STRIPE_SECRET_KEY))
  final stripe = Stripe('sk_test_...');

  try {
    // Create payment intent (equivalent to stripe.paymentIntents.create())
    final paymentIntent = await stripe.createPaymentIntent(
      CreatePaymentIntentRequest(
        amount: 1000, // $10.00
        currency: 'usd',
        paymentMethodTypes: ['card'],
        metadata: {'order_id': '12345'},
      ),
    );

    print('Payment Intent created: ${paymentIntent.id}');

    // Create customer (equivalent to stripe.customers.create())
    final customer = await stripe.createCustomer(
      CreateCustomerRequest(
        email: 'customer@example.com',
        name: 'John Doe',
      ),
    );

    print('Customer created: ${customer.id}');

  } catch (e) {
    print('Error: $e');
  }
}


