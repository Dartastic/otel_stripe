// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

/// Attribute keys for the Stripe → OTel bridge.
///
/// OTel has no `payments.*` semantic convention yet; these
/// `stripe.*` keys are package-local. Stable across the 0.x line.
enum StripeBridgeSemantics implements OTelSemantic {
  /// `stripe.resource` — Stripe API resource (`PaymentIntent`,
  /// `Customer`, `Subscription`, `Charge`, `Refund`, `Invoice`,
  /// `SetupIntent`, etc.).
  resource('stripe.resource'),

  /// `stripe.operation` — verb performed (`create`, `retrieve`,
  /// `update`, `cancel`, `confirm`, `capture`, `list`, etc.).
  operation('stripe.operation'),

  /// `stripe.object_id` — Stripe object id when known (e.g.
  /// `pi_xxx`, `cus_xxx`, `sub_xxx`).
  objectId('stripe.object_id'),

  /// `stripe.customer_id` — customer this call is associated with.
  customerId('stripe.customer_id'),

  /// `stripe.payment_method` — type of payment method
  /// (`card`, `link`, `apple_pay`, `google_pay`, ...).
  paymentMethod('stripe.payment_method'),

  /// `stripe.amount` — amount in the smallest currency unit (cents
  /// for USD). Matches Stripe's wire format.
  amount('stripe.amount'),

  /// `stripe.currency` — ISO-4217 currency code (lowercase per
  /// Stripe convention, e.g. `usd`, `eur`).
  currency('stripe.currency'),

  /// `stripe.status` — final object status after the call
  /// (`succeeded`, `requires_payment_method`, `processing`,
  /// `canceled`, `paid`, `unpaid`, …).
  status('stripe.status'),

  /// `stripe.livemode` — `true` for live keys, `false` for test.
  livemode('stripe.livemode');

  const StripeBridgeSemantics(this.key);

  @override
  final String key;

  @override
  String toString() => key;
}
