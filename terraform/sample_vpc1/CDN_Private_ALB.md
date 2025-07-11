# CloudFront to ECS via Private ALB: Three Integration Options

## Overview
This document describes three AWS-supported patterns to connect CloudFront to a private ALB (or any private VPC resource):

---

### 1. AWS PrivateLink (VPC Endpoint Service)

**How it works:**
- You create a VPC Endpoint Service for your private ALB.
- In a VPC that CloudFront can access (often a public VPC), you create an Interface VPC Endpoint that connects to your Endpoint Service.
- You set up a custom domain (using Route 53) that resolves to the VPC Endpoint’s private IP.
- CloudFront uses this custom domain as its origin.

**Pros:**
- Secure, private connectivity (never exposes your ALB to the public internet).
- Scalable and AWS-native.

**Cons:**
- More complex to set up (requires Endpoint Service, Endpoint, and DNS).
- Slightly higher cost due to PrivateLink data processing.

---

### 2. Public NLB as a Proxy

**How it works:**
- You deploy a public Network Load Balancer (NLB) in your VPC.
- The NLB forwards traffic to your private ALB (or directly to your ECS services).
- CloudFront uses the public DNS of the NLB as its origin.

**Pros:**
- Simple to set up.
- No need for PrivateLink or custom DNS.

**Cons:**
- Your NLB is public, so you must secure it (e.g., with security groups, WAF, or allow-lists).
- Not as private as PrivateLink.

---

### 3. API Gateway or Lambda@Edge as a Proxy

**How it works:**
- You create an API Gateway (public) or Lambda@Edge function.
- The API Gateway or Lambda@Edge proxies requests from CloudFront to your private ALB.
- CloudFront uses the API Gateway endpoint or Lambda@Edge as its origin.

**Pros:**
- Flexible (can add authentication, logging, transformation, etc.).
- API Gateway can be protected with WAF, throttling, etc.

**Cons:**
- More moving parts and potential latency.
- May require VPC integration for API Gateway (which can be complex and costly).

---

## Summary Table

| Method                 | Security      | Complexity | Cost   | Use Case                         |
|------------------------|--------------|------------|--------|-----------------------------------|
| PrivateLink            | Private      | High       | Med/Hi | Enterprise, strict compliance     |
| Public NLB             | Public       | Low        | Low    | Simpler, less strict environments |
| API Gateway/Lambda@Edge| Public/Hybrid| Med        | Med    | Custom logic, API, transformation |

---

## Example Architecture (NLB Proxy)

```
[Internet]
   |
[CloudFront]
   |
[Public NLB]  <-- New!
   |
[Private ALB] (path-based routing)
   |
[ECS Services (Fargate)]
```

- CloudFront uses the public NLB DNS as an origin.
- NLB forwards all traffic to the private ALB.
- The ALB performs path-based routing to ECS services (e.g., /web, /api, /app).
- Security groups and health checks must allow NLB-to-ALB and ALB-to-ECS traffic.
- **Limitation:** ALB private IPs must be manually registered as NLB targets. If the ALB is restarted or replaced, its IPs may change and you must update the NLB target group.
- **Note:** ALBs do not support Elastic IPs. This pattern is best for test/lab environments or where you can automate NLB target updates. For production, consider using ALB directly or PrivateLink for more robust automation.

---