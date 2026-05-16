// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// OpenTelemetry bridge for Stripe API calls.
///
/// Works with `package:stripe` (server-side), `package:flutter_stripe`
/// (mobile UI), and raw HTTP — wrap your existing call in
/// `tracedStripeCall(...)` and return a [StripeCallResult] carrying
/// the response value and a [StripeResult] of fields to record on
/// the span (`stripe.object_id`, `stripe.status`, amount, currency,
/// payment method, livemode).
library;

export 'src/otel_stripe.dart';
export 'src/otel_stripe_suppression.dart';
export 'src/stripe_semantics.dart';
