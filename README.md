# DreamSync — Ivy

- **Website link:** https://orgfarm-22349fde76.my.site.com/eh/
- **Salesforce Org:** https://orgfarm-22349fde76.lightning.force.com/one/one.app

Where systems meet sustainability.

**Ivy** is an Agentforce agent that tracks, reduces, and reports a home‑furnishings
company's carbon footprint in real time — turning scattered emissions data into a
single, actionable view for the people who design, build, and sell the product.

Built for the **Agentforce for Good Hackathon — Dreamforce 2026**, Earthforce Track
(1 of 16 Salesforce Equality Groups), by **Team DreamSync**.

---

## The problem

Earthique Homes delivers high‑quality furniture with a measurably lower carbon
footprint across its lifecycle — from sourcing and manufacturing to durable design,
repair, reuse, and end‑of‑life recovery. But like most home‑furnishings companies,
it struggles to actually track and reduce that footprint:

- Emissions data is siloed across BOMs, suppliers, and shipments — no full picture.
- Design and logistics teams lack real‑time visibility into product‑ and
  shipment‑level carbon hotspots.
- Leadership needs automated, auditable sustainability reporting to track
  performance and meet stakeholder expectations.

## The solution

A unified emissions platform, built on **Salesforce Data Cloud**, with three agents
doing the work:

| Agent | What it does |
| --- | --- |
| **Product Emissions Agent** | Calculates and compares CO₂e per SKU, and runs "what‑if" scenarios for greener design choices |
| **Supply‑Chain Emissions Agent** | Monitors shipments, flags high‑emission routes, and recommends more sustainable logistics alternatives |
| **Predictive Agent** | Generates real‑time executive dashboards, KPI tiles, and audit logs for transparent reporting |

Ivy sits in front of all three — the single conversational entry point for anyone
who needs an answer, whether that's a manufacturer asking about a sofa's materials
or a customer booking a carbon consultation.

**Outcome:** the business can confidently measure, reduce, and report carbon
performance product by product, shipment by shipment — strengthening its
sustainability leadership.

**Built with:** Salesforce Data Cloud, CRM, Agentforce, Agentforce Voice, Meta.

---

## How it is built

Ivy is an **Agentforce agent** with topics and actions grounded in Salesforce Data
Cloud, backed by Apex actions and generative prompt templates. Messaging channels
route conversations in from the Earthique Homes website and Facebook, with
automated escalation to a human service agent when a conversation needs one.

| Path | What lives there |
| --- | --- |
| `force-app/main/default/aiAuthoringBundles/` | Ivy — the agent itself, its topics and actions |
| `force-app/main/default/genAiPromptTemplates/` | Prompt templates behind the agent's responses |
| `force-app/main/default/classes/` | Apex actions the agent calls into |
| `force-app/main/default/messagingChannels/` | Website and Facebook messaging channels |
| `force-app/main/default/embeddedServiceConfig/` | Embedded chat widget configuration |
| `force-app/main/default/escalationRules/` | Rules that hand a conversation to a human agent |
| `force-app/main/default/flexipages/` | The messaging session console the human agent works from |

> Folder paths above are based on the metadata visible in the project so far —
> update this table as the structure settles, especially once the Data Cloud
> objects, streams, and predictive model artifacts are added.


## How it works

**Jacob**, a manufacturer, needs to know the CO₂e impact of the sofa he's building —
materials, transport, the works. Instead of chasing that information across
multiple people and websites, he asks Ivy directly.

Ivy pulls from:

- **CRM** — BOM, emission factors, and product data
- **SFTP batch ingestion** — products, manufacturing, and transport records
- **Streaming ingestion** — live material and transport emission data
- **RAG over unstructured data** — materials and manufacturing detail PDFs
- **A predictive model** — trained on product, material, cost, and emission
  parameters

From that, Ivy returns the emission factors, flags the highest‑ and lowest‑impact
choices, and predicts whether a product trends toward "green" or stays "red." It
can also route a request to Meta or the website, book a carbon consultation via
email, and — when a question needs a person — hand the conversation to a **human
service agent** without losing context.

Behind the scenes: **Apex + Prompt Templates** drive the logic, with Salesforce
Data 360 unifying the CRM, SFTP, and streaming sources so every agent reasons over
the same data.

---

## Responsible & accessible by design

- **Einstein Trust Layer** handles grounding, privacy, toxicity filtering, bias
  detection, and audit logging — responsible AI is intrinsic, not bolted on.
- **RAI Self‑Check Skill** is built into every sub‑agent and topic, mitigating risk
  at the source rather than after the fact.
- **Agentforce Voice** enables hands‑free, conversational access, so users with
  visual, motor, or cognitive impairments can fully use the platform — reducing
  barriers to digital engagement for every customer segment.

## Expected impact

| Area | Impact |
| --- | --- |
| **Business** | Empowers customers to make sustainable choices, differentiates the brand as a sustainability leader, and automates customer support |
| **Environment** | Lowers embodied carbon through smarter material recommendations, cuts waste from inefficient design/production choices, and extends product life through durability and repair guidance |
| **Market** | Creates a competitive edge in a sustainability‑focused market, supports regulatory and reporting requirements, and attracts eco‑conscious customers and partners |
| **Cost** | Recommends lower‑cost, lower‑emission materials, reduces manual support workload, and optimizes the supply chain through smarter insights |

## More

| Document | What is in it |
| --- | --- |
| [DreamSync.pptx](https://github.com/kpruthvirj/DreamSync/blob/main/Hackathon_Sep26_DreamSync.pptx) | Architecture: agent topics, actions, data flows, and why the design choices are what they are |
| [ACCESSIBILITY.md](https://github.com/kpruthvirj/DreamSync/blob/main/Accessibility_RAI_Trust_Compliance.md) | Accessibility approach, RAI Self-Check details |
| [Ivvy.agent](https://github.com/kpruthvirj/DreamSync/blob/main/force-app/main/default/aiAuthoringBundles/Ivy/Ivy.agent) | Agent Configration |
| [APEX_Classes ](https://github.com/kpruthvirj/DreamSync/tree/main/force-app/main/default/classes) | Apex classes |
| [Predictive Model ](https://orgfarm-22349fde76.lightning.force.com/lightning/n/standard-EinsteinStudio?c__assetId=24sfj0000005OMfAAM#eyJkZXRhaWxzVGFiIjoiT1ZFUlZJRVcifQ==) | Predictive Model |

## Team

**Team DreamSync** — Agentforce for Good Hackathon, Dreamforce 2026, Earthforce Track.