# CI/CD and APIOps

## Summary

APIOps applies GitOps and DevOps principles to the API lifecycle: every change to an API spec, configuration, or gateway definition flows through version control and automated pipelines. Done well, APIOps eliminates "configuration drift" where the deployed API diverges from the spec, catches breaking changes before deployment, and enables consistent promotion across environments. This file covers pipeline design, tooling, and the practical constraints that make APIOps harder than it sounds.

---

## What APIOps Actually Means

APIOps is not a product. It's a set of practices:

1. **Spec as code:** OpenAPI/AsyncAPI specs are version-controlled in git alongside application code (not generated from running code or maintained separately in a portal)
2. **Lint-and-gate:** Automated linting of specs blocks PRs with style violations or breaking changes
3. **Mock-before-build:** Mock servers generated from specs enable frontend/integration work before implementation
4. **Contract-first testing:** Tests validate the running API against the contract (Schemathesis, Pact)
5. **Gateway-as-code:** API gateway configurations (Kong decK, APIM ARM templates, AWS API GW CloudFormation) are version-controlled and deployed by pipeline
6. **Environment promotion:** APIs flow through dev → staging → production with consistent validation at each gate

The term is most associated with the Microsoft Azure APIOps toolkit and Kong, but the principles apply to any API management platform.

---

## Pipeline Architecture: Design → Deploy

### Minimal Viable APIOps Pipeline

```text
┌─────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────┐
│  PR Opens   │────▶│   Lint       │────▶│  Break Check │────▶│  Mock    │
│  (spec edit)│     │ (Spectral)   │     │ (oasdiff)    │     │ (Prism)  │
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
                                                                      │
                                                              Tests against mock
                                                                      │
┌─────────────┐     ┌──────────────┐     ┌──────────────┐           ▼
│  Production │◀────│   Staging    │◀────│    Dev       │◀────┌──────────┐
│  Deploy     │     │  Promote     │     │  Deploy      │     │  PR Merge│
└─────────────┘     └──────────────┘     └──────────────┘     └──────────┘
      │                                          │
   E2E Tests                              Integration Tests
   Schemathesis                           Schemathesis
   k6 smoke                               Contract tests (Pact)
```

### Full Pipeline with Gates

```yaml
# .github/workflows/api-pipeline.yml
name: API Pipeline

on:
  pull_request:
    paths: ['openapi.yaml', 'src/api/**']
  push:
    branches: [main]

jobs:
  lint:
    name: Lint API Spec
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Spectral Lint
        uses: stoplightio/spectral-action@latest
        with:
          file_glob: 'openapi.yaml'
          spectral_ruleset: '.spectral.yaml'
      
      - name: Run vacuum lint (fast alternative)
        run: |
          docker run --rm -v $(pwd):/work quay.io/slushy/vacuum:latest \
            lint -r /work/.spectral.yaml /work/openapi.yaml

  breaking-change-detection:
    name: Check for Breaking Changes
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: Get base spec
        run: git show origin/main:openapi.yaml > openapi-base.yaml
        
      - name: Run oasdiff
        run: |
          docker run --rm \
            -v $(pwd):/work \
            tufin/oasdiff breaking \
            /work/openapi-base.yaml \
            /work/openapi.yaml \
            --fail-on ERR

  mock-and-test:
    name: Mock and Schema Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Start mock server
        run: |
          npm install -g @stoplight/prism-cli
          prism mock openapi.yaml &
          sleep 3  # Wait for server
          
      - name: Run Schemathesis against mock
        run: |
          schemathesis run http://localhost:4010/openapi.json \
            --checks not_a_server_error,response_schema_conformance \
            --hypothesis-max-examples=50

  security-scan:
    name: API Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: 42Crunch Security Audit
        uses: 42crunch/api-security-audit-action@v3
        with:
          api-token: ${{ secrets.CRUNCH_API_TOKEN }}
          default-collection-name: 'API Security Review'

  deploy-dev:
    name: Deploy to Dev
    needs: [lint, mock-and-test, security-scan]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy application
        run: ./scripts/deploy.sh dev
        
      - name: Run integration tests
        run: |
          schemathesis run $DEV_URL/openapi.json \
            --checks all \
            --auth "Authorization: Bearer $DEV_TOKEN"
            
      - name: Run contract verification
        run: npm run pact:verify -- --provider-url $DEV_URL
        
      - name: Run smoke test
        run: |
          k6 run --env BASE_URL=$DEV_URL tests/smoke.js

  promote-staging:
    name: Promote to Staging
    needs: deploy-dev
    environment: staging
    runs-on: ubuntu-latest
    steps:
      - name: Promote artifact
        run: ./scripts/promote.sh dev staging
        
      - name: Run k6 load test
        run: |
          k6 run \
            --env BASE_URL=$STAGING_URL \
            --vus 100 --duration 10m \
            tests/load.js
            
      - name: Pact can-i-deploy check
        run: |
          pact-broker can-i-deploy \
            --pacticipant $SERVICE_NAME \
            --version $GITHUB_SHA \
            --to-environment staging
```

---

## OpenAPI in CI: Key Tooling

### Spectral Lint Gate

The lint gate blocks PRs that violate API style rules. Critical rules to enforce:

```yaml
# .spectral.yaml
extends: spectral:oas

rules:
  # Require operationId on all operations
  operation-operationId:
    severity: error
    
  # Require tags
  operation-tag-defined:
    severity: error
    
  # Require description on all schemas
  oas3-schema-description:
    severity: warn
    given: "$.components.schemas[*]"
    then:
      field: description
      function: truthy
      
  # No 200 for creation — must be 201
  post-returns-201:
    severity: error
    given: "$.paths[*].post.responses"
    then:
      field: "201"
      function: truthy
      
  # Require examples on all request bodies
  require-request-body-examples:
    severity: warn
    given: "$.paths[*][post,put,patch].requestBody.content[*]"
    then:
      field: example
      function: truthy
```

**Severity escalation strategy:** Start with `warn` on new rules; switch to `error` after existing specs are updated. This avoids breaking existing CI while migrating.

### Breaking Change Detection in PRs

`oasdiff` provides the most practical breaking change detection:

```bash
# Check for breaking changes between main and PR branch
oasdiff breaking \
  --load-from-url https://api.github.com/repos/org/repo/contents/openapi.yaml?ref=main \
  --load-from-url https://raw.githubusercontent.com/org/repo/feat/openapi.yaml \
  --fail-on ERR

# Breaking change types detected:
# RESPONSE_BODY_DELETED - field removed from response
# REQUEST_BODY_SCHEMA_PROPERTY_REQUIRED - field became required
# API_PATH_DELETED - endpoint removed
# RESPONSE_STATUS_DELETED - status code removed
# SCHEMA_TYPE_CHANGED - field type changed
```

**Policy options:**

1. **Block all breaking changes:** Forces semver discipline; version bump required for any breaking change
2. **Require manual approval for breaking changes:** PR comment bot flags breaking changes; team lead must approve
3. **Report only:** Breaking changes logged but don't block (use for established codebases that tolerate some drift)

Most teams start at option 2 and move to option 1 as discipline matures.

---

## Gateway-as-Code

Defining API gateway configuration in version control enables reproducible deployments and environment parity.

### Kong Gateway with decK

decK (Declarative Configuration for Kong) manages Kong configuration as YAML:

```yaml
# kong.yaml
_format_version: "3.0"

services:
  - name: orders-service
    url: http://orders-service:8080
    connect_timeout: 5000
    read_timeout: 30000
    routes:
      - name: orders-api
        paths: [/v1/orders]
        methods: [GET, POST, PUT, DELETE]
        strip_path: false
    plugins:
      - name: rate-limiting
        config:
          minute: 100
          policy: redis
          redis_host: redis
      - name: jwt
        config:
          secret_is_base64: false
          key_claim_name: iss
      - name: request-transformer
        config:
          add:
            headers: [X-Service-Version:1.0]
```

```bash
# Deploy Kong config (idempotent)
deck sync --state kong.yaml --kong-addr http://kong:8001

# Diff without applying (CI check)
deck diff --state kong.yaml --kong-addr http://kong:8001

# Export running config (initial capture)
deck dump --output-file kong-exported.yaml
```

### AWS API Gateway with CloudFormation/SAM

```yaml
# template.yaml
AWSTemplateFormatVersion: '2010-09-09'
Transform: AWS::Serverless-2016-10-31

Resources:
  OrdersAPI:
    Type: AWS::Serverless::Api
    Properties:
      StageName: !Ref Stage
      DefinitionBody:
        Fn::Transform:
          Name: AWS::Include
          Parameters:
            Location: openapi.yaml  # Reference your OpenAPI spec
      Auth:
        DefaultAuthorizer: CognitoAuthorizer
        Authorizers:
          CognitoAuthorizer:
            UserPoolArn: !GetAtt UserPool.Arn
      AccessLogSetting:
        DestinationArn: !GetAtt APILogGroup.Arn
      MethodSettings:
        - LoggingLevel: INFO
          MetricsEnabled: true
          ResourcePath: '/*'
          HttpMethod: '*'
```

### Azure APIM via APIOps

The Azure APIOps toolkit synchronizes APIM configuration from a git repository:

```text
apim-repo/
├── apis/
│   └── orders-api/
│       ├── apiInformation.json    # API metadata
│       ├── specification.yaml     # OpenAPI spec
│       └── policy.xml             # APIM policy (XML)
├── products/
│   └── premium-product/
│       └── productInformation.json
└── named-values/
    └── backend-url.json
```

Pipeline extracts from APIM → stores in git → deploys from git to APIM. Git becomes the source of truth.

---

## Automated SDK Generation in CI

Generating SDKs from OpenAPI specs in CI ensures clients always reflect the current API:

### openapi-generator

```yaml
# CI step
- name: Generate TypeScript SDK
  run: |
    docker run --rm \
      -v $(pwd):/local \
      openapitools/openapi-generator-cli generate \
      -i /local/openapi.yaml \
      -g typescript-axios \
      -o /local/sdk/typescript \
      --additional-properties=npmName=@example/api-client

- name: Publish SDK
  if: github.ref == 'refs/heads/main'
  run: |
    cd sdk/typescript
    npm publish --access public
```

### Fern

Fern generates idiomatic SDKs (not just OpenAPI-generator output) with better ergonomics:

```yaml
# fern/api/definition/openapi.yml (points to your spec)

# fern/generators.yml
default-group: local
groups:
  local:
    generators:
      - name: fernapi/fern-typescript-node-sdk
        version: 0.9.5
        output:
          location: local-file-system
          path: ../generated/typescript
      - name: fernapi/fern-python-sdk
        version: 1.1.0
        output:
          location: local-file-system
          path: ../generated/python
```

Fern produces SDKs that handle pagination, authentication, and error handling idiomatically in each language — closer to Stripe's handcrafted SDKs than openapi-generator's mechanical output.

### Stainless

Stainless (Y Combinator funded, 2022) takes a higher-level approach to SDK generation. It reads your OpenAPI spec and applies inferred conventions to produce SDKs indistinguishable from handcrafted ones. Used by Anthropic, OpenAI (their official Python/TypeScript SDKs are Stainless-generated), and several financial API companies.

---

## API Catalog/Registry as Code

An API catalog provides discoverability and governance across an organization's API portfolio. Backstage (Spotify) is the most common open-source implementation:

```yaml
# catalog-info.yaml (in each service repo)
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: orders-service
  description: Order management API
  tags: [orders, commerce]
  annotations:
    github.com/project-slug: 'org/orders-service'
    backstage.io/techdocs-ref: dir:.
spec:
  type: openapi
  lifecycle: production
  owner: team-commerce
  definition:
    $text: ./openapi.yaml
```

Backstage auto-discovers APIs via entity providers that scan repos for `catalog-info.yaml`. Result: a searchable catalog of all APIs with ownership, lifecycle stage, documentation, and dependency graphs.

---

## Canary and Blue-Green Deployments for APIs

### Blue-Green

Two identical environments. Traffic switches from blue to green:

```yaml
# AWS Application Load Balancer — traffic shifting
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions \
    Type=forward,TargetGroupArn=$GREEN_TG_ARN  # Switch 100% to green
```

**For APIs:** Blue-green is appropriate when you can't have both versions in production simultaneously (data model changes that affect both). The downside is the cut-over moment — if green has issues, rollback requires another switch.

### Canary Releases

Route a percentage of traffic to the new version:

```yaml
# Kong traffic splitting plugin
plugins:
  - name: canary
    config:
      percentage: 10        # 10% to canary
      upstream_host: orders-service-v2
      upstream_fallback: true
      hash_on: consumer    # Consistent routing per consumer
```

**Canary for APIs:** More appropriate than blue-green for most API changes. Validate the new version handles real traffic before full rollout. Key metrics to monitor during canary:

- Error rate (compare v1 vs v2 cohorts)
- P95/P99 latency
- Business metrics (order completion rate, etc.)

**Automatic canary promotion (Flagger + Kubernetes):**

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: orders-api
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: orders-api
  progressDeadlineSeconds: 600
  analysis:
    interval: 1m
    threshold: 5        # 5 failed checks = rollback
    maxWeight: 50       # Max 50% traffic to canary
    stepWeight: 10      # Increase 10% per interval
    metrics:
      - name: request-success-rate
        thresholdRange:
          min: 99
        interval: 1m
      - name: request-duration
        thresholdRange:
          max: 500
        interval: 1m
```

---

## Shift-Left API Security in CI

Security checks in CI (before deployment) catch issues early:

**42Crunch API Security Audit:**

- Static analysis of OpenAPI spec
- Detects: missing auth on endpoints, overly permissive CORS definitions, missing input validation schemas, exposed PII in responses
- Provides a numeric score (0-100)
- CI integration via GitHub Action

**OWASP ZAP DAST (on staging):**

- Run against the deployed staging environment
- Active scan attempts actual attacks (SQL injection, XSS, etc.)
- Passive scan observes traffic and flags issues

**Pipeline placement:**

```text
PR Gate: Spectral lint → oasdiff breaking change → 42Crunch spec audit
Staging Gate: ZAP passive scan → Schemathesis → Nuclei templates
Production Promotion: ZAP active scan results reviewed, can-i-deploy
```

---

## Key References

- [Azure APIOps Toolkit](https://github.com/Azure/apiops)
- [Kong decK Documentation](https://docs.konghq.com/deck/)
- [APIOps for Automated API Version Control — Zuplo](https://zuplo.com/learning-center/apiops-for-automated-api-version-control)
- [Spectral CI Integration](https://docs.stoplight.io/docs/spectral/ZG9jOjYyMDc0NA-github-action)
- [oasdiff Breaking Change Detection](https://github.com/tufin/oasdiff)
- [Flagger Progressive Delivery](https://flagger.app/)
- [42Crunch API Security Audit GitHub Action](https://github.com/42Crunch/api-security-audit-action)
- [Fern SDK Generator](https://buildwithfern.com/)
- [Stainless SDK Generator](https://www.stainlessapi.com/)
- [Backstage API Catalog](https://backstage.io/docs/features/software-catalog/descriptor-format#kind-api)
- [openapi-generator](https://openapi-generator.tech/)
