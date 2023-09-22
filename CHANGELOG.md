## 0.6.0
- Issue: Fix Ruby 3.2 problems.

## 0.5.14
- Feature: Support alias record of S3 endpoint and ELB in us-east-2.

## 0.5.13
- Feature: Submit single change batch per hosted zone on apply.
- Feature: Support alias record of AWS Global Accelerator.
- Issue: Fix priority between CNAME change and ALIAS change.

## 0.5.12
- Issue: Fix sorting resource\_records with aws-sdk-core v3.44.1 or later.

## 0.5.11
- Feature: Update aws-sdk-core for handling PriorRequestNotComplete error as throttling error.

## 0.5.10
- Feature: Support dns\_name of Network Load Balancer.
- Feature: Support VPCE dns\_name.

## 0.5.9
- Feature: Support CloudWatch Metrics Health Check.

## 0.5.7
- Issue: Fix for `dualstack` prefix.
- Feature: Use constant for CanonicalHostedZoneNameID.

## 0.5.6
- Feature: Disable HealthCheck GC (pass `--health-check-gc` option if enable).
- Feature: Support Calculated Health Checks.
- Feature: Support New Health Check attributes.
- Feature: Add template feature.

## 0.5.5
- Feature: **Disable Divided HostedZone**
- Feature: **Use aws-sdk v2** [PR#20](https://github.com/winebarrel/roadworker/pull/20)
- Feature: Support Cross Account ELB Alias [PR#21](https://github.com/winebarrel/roadworker/pull/21)

## 0.4.3
- Feature: Compare resource records ignoring the order.
