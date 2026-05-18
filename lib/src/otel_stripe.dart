// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_stripe_suppression.dart';
import 'stripe_semantics.dart';

const _tracerName = 'dartastic_otel_libs_stripe';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

/// Result-side fields the caller fills in after the Stripe API
/// returns — surfaces as `stripe.*` attrs on the emitted span.
///
/// All fields nullable; the bridge skips attrs the caller leaves
/// unset.
class StripeResult {
  /// Creates a result.
  const StripeResult({
    this.objectId,
    this.status,
    this.amount,
    this.currency,
    this.paymentMethod,
    this.livemode,
  });

  /// `id` from the Stripe response (`pi_xxx`, `cus_xxx`, ...).
  final String? objectId;

  /// `status` field (`succeeded`, `requires_payment_method`, ...).
  final String? status;

  /// Final amount in smallest currency unit. Stripe responses echo
  /// the requested amount; setting it here documents the value on
  /// the response side of the trace, useful for refunds and partial
  /// captures.
  final int? amount;

  /// ISO-4217 lowercase currency (`usd`, `eur`).
  final String? currency;

  /// Payment method type (`card`, `apple_pay`, ...).
  final String? paymentMethod;

  /// `livemode` flag from the response.
  final bool? livemode;
}

/// Pair returned from a `tracedStripeCall` invoke callback.
class StripeCallResult<T> {
  const StripeCallResult({required this.value, this.result});
  final T value;
  final StripeResult? result;
}

/// Wraps a Stripe API call in a CLIENT span.
///
/// Stripe has a server-side Dart SDK (`package:stripe`) and a mobile
/// UI SDK (`package:flutter_stripe`). The bridge is invocation-
/// pattern-shaped so it works with both — and with raw HTTP calls
/// to Stripe's REST API.
///
/// ```dart
/// final intent = await tracedStripeCall<PaymentIntent>(
///   resource: 'PaymentIntent',
///   operation: 'create',
///   amount: 4999,
///   currency: 'usd',
///   customerId: customer.id,
///   invoke: () async {
///     final pi = await stripe.paymentIntents.create(
///       amount: 4999,
///       currency: 'usd',
///       customer: customer.id,
///     );
///     return StripeCallResult(
///       value: pi,
///       result: StripeResult(
///         objectId: pi.id,
///         status: pi.status.name,
///         amount: pi.amount,
///         currency: pi.currency,
///         livemode: pi.livemode,
///       ),
///     );
///   },
/// );
/// ```
///
/// Span name format: `stripe.<resource> <operation>` (e.g.
/// `stripe.PaymentIntent create`).
Future<T> tracedStripeCall<T>({
  required String resource,
  required String operation,
  required Future<StripeCallResult<T>> Function() invoke,
  int? amount,
  String? currency,
  String? customerId,
  String? paymentMethod,
}) async {
  if (stripeInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }

  final span = _tracer().startSpan(
    'stripe.$resource $operation',
    kind: SpanKind.client,
    attributes: _requestAttrs(
      resource: resource,
      operation: operation,
      amount: amount,
      currency: currency,
      customerId: customerId,
      paymentMethod: paymentMethod,
    ),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      span.addAttributes(_responseAttrs(r.result!));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(
      OTel.attributes([
        OTel.attributeString(
          ErrorResource.errorType.key,
          e.runtimeType.toString(),
        ),
      ]),
    );
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

Attributes _requestAttrs({
  required String resource,
  required String operation,
  int? amount,
  String? currency,
  String? customerId,
  String? paymentMethod,
}) {
  final m = <String, Object>{
    StripeBridgeSemantics.resource.key: resource,
    StripeBridgeSemantics.operation.key: operation,
  };
  if (amount != null) m[StripeBridgeSemantics.amount.key] = amount;
  if (currency != null) m[StripeBridgeSemantics.currency.key] = currency;
  if (customerId != null) {
    m[StripeBridgeSemantics.customerId.key] = customerId;
  }
  if (paymentMethod != null) {
    m[StripeBridgeSemantics.paymentMethod.key] = paymentMethod;
  }
  return OTel.attributesFromMap(m);
}

Attributes _responseAttrs(StripeResult r) {
  final attrs = <Attribute<Object>>[];
  if (r.objectId != null) {
    attrs.add(OTel.attributeString(
      StripeBridgeSemantics.objectId.key,
      r.objectId!,
    ));
  }
  if (r.status != null) {
    attrs
        .add(OTel.attributeString(StripeBridgeSemantics.status.key, r.status!));
  }
  if (r.amount != null) {
    attrs.add(OTel.attributeInt(StripeBridgeSemantics.amount.key, r.amount!));
  }
  if (r.currency != null) {
    attrs.add(OTel.attributeString(
      StripeBridgeSemantics.currency.key,
      r.currency!,
    ));
  }
  if (r.paymentMethod != null) {
    attrs.add(OTel.attributeString(
      StripeBridgeSemantics.paymentMethod.key,
      r.paymentMethod!,
    ));
  }
  if (r.livemode != null) {
    attrs.add(OTel.attributeBool(
      StripeBridgeSemantics.livemode.key,
      r.livemode!,
    ));
  }
  return OTel.attributes(attrs);
}
