// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_stripe/otel_stripe.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_stripe-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span span) {
    return {for (final a in span.attributes.toList()) a.key: a.value};
  }

  group('tracedStripeCall', () {
    test('emits CLIENT span with stripe.* request + response attrs', () async {
      final pi = await tracedStripeCall<String>(
        resource: 'PaymentIntent',
        operation: 'create',
        amount: 4999,
        currency: 'usd',
        customerId: 'cus_abc',
        paymentMethod: 'card',
        invoke: () async => const StripeCallResult(
          value: 'pi_123',
          result: StripeResult(
            objectId: 'pi_123',
            status: 'requires_confirmation',
            amount: 4999,
            currency: 'usd',
            paymentMethod: 'card',
            livemode: false,
          ),
        ),
      );
      expect(pi, 'pi_123');

      final span = spans.findSpanByName('stripe.PaymentIntent create');
      expect(span, isNotNull);
      expect(span!.kind, SpanKind.client);
      final a = attrsOf(span);
      expect(a['stripe.resource'], 'PaymentIntent');
      expect(a['stripe.operation'], 'create');
      expect(a['stripe.amount'], 4999);
      expect(a['stripe.currency'], 'usd');
      expect(a['stripe.customer_id'], 'cus_abc');
      expect(a['stripe.payment_method'], 'card');
      expect(a['stripe.object_id'], 'pi_123');
      expect(a['stripe.status'], 'requires_confirmation');
      expect(a['stripe.livemode'], false);
    });

    test('records exception on throw', () async {
      await expectLater(
        tracedStripeCall<String>(
          resource: 'PaymentIntent',
          operation: 'confirm',
          invoke: () async => throw StateError('card_declined'),
        ),
        throwsA(isA<StateError>()),
      );
      final span = spans.findSpanByName('stripe.PaymentIntent confirm');
      expect(span!.status, SpanStatusCode.Error);
      expect(attrsOf(span)['error.type'], 'StateError');
    });

    test('omits optional attrs when caller did not set them', () async {
      await tracedStripeCall<String>(
        resource: 'Customer',
        operation: 'retrieve',
        invoke: () async => const StripeCallResult(value: 'ok'),
      );
      final span = spans.findSpanByName('stripe.Customer retrieve');
      final a = attrsOf(span!);
      expect(a.containsKey('stripe.amount'), isFalse);
      expect(a.containsKey('stripe.currency'), isFalse);
      expect(a.containsKey('stripe.object_id'), isFalse);
    });

    test('different resource/operation combos produce distinct spans',
        () async {
      await tracedStripeCall<int>(
        resource: 'Charge',
        operation: 'refund',
        amount: 1000,
        currency: 'usd',
        invoke: () async => const StripeCallResult(value: 0),
      );
      await tracedStripeCall<int>(
        resource: 'Subscription',
        operation: 'cancel',
        customerId: 'cus_x',
        invoke: () async => const StripeCallResult(value: 0),
      );
      expect(spans.findSpanByName('stripe.Charge refund'), isNotNull);
      expect(spans.findSpanByName('stripe.Subscription cancel'), isNotNull);
    });

    test('zone-scoped suppression skips the span', () async {
      final v = await runWithoutStripeInstrumentationAsync(() async {
        return tracedStripeCall<String>(
          resource: 'PaymentIntent',
          operation: 'create',
          invoke: () async => const StripeCallResult(value: 'pi_silent'),
        );
      });
      expect(v, 'pi_silent');
      expect(spans.findSpansStartingWith('stripe.'), isEmpty);
    });
  });
}
