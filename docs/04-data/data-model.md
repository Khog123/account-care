# Account Care V1 — Data Model

**Status:** Approved design baseline  
**Product:** Account Care Commercial Desktop V1  
**Database:** SQLite via Drift  
**Cloud Database:** PostgreSQL  
**Primary Platform:** Windows Desktop

---

# 1. Purpose

This document translates the Account Care domain model into a logical data model.

It defines:

- Persistent entities
- Primary keys
- Relationships
- Business ownership
- Monetary representation
- Date/time representation
- Status fields
- Soft deletion
- Constraints
- Indexing requirements
- Transaction boundaries
- SQLite/Drift considerations

This is still a **logical data model**.

It is not yet the Dart/Drift implementation.

The physical Drift schema will be created after this model is reviewed.

---

# 2. Database Architecture

Account Care V1 uses a local-first database architecture.

```text
Flutter Desktop
      │
      ▼
Application Services
      │
      ▼
Repositories
      │
      ▼
Drift
      │
      ▼
SQLite
```

The local SQLite database is the operational source of truth for the desktop application.

Cloud storage is optional and is used for backup/convenience.

```text
Local SQLite
    │
    ├── Normal business operation
    │
    └── Optional encrypted backup
              │
              ▼
         Cloud Storage
```

Cloud availability must not be required for normal POS operation.

---

# 3. Business/Tenant Boundary

The primary ownership boundary is:

```text
Business
```

Business-owned records must contain a `business_id` or an equivalent ownership relationship.

Conceptually:

```text
Business
├── Users
├── Categories
├── Products
├── Customers
├── Sales
├── SaleItems
├── Payments
├── LedgerEntries
├── InventoryMovements
├── Expenses
└── AuditEvents
```

---

# 4. Business Isolation

Every application query involving business-owned data must operate within the authenticated/current business context.

Example:

```text
Current Business
      ↓
Repository
      ↓
WHERE business_id = currentBusinessId
```

However, business isolation must not depend only on UI filtering.

Repositories and application services must enforce the business boundary.

The backend must independently enforce tenant authorization when cloud APIs are used.

---

# 5. Primary Key Strategy

All major persistent entities should use stable unique identifiers.

The application should not depend on auto-increment integer IDs as the only identity mechanism.

Recommended logical identifier:

```text
UUID
```

Example:

```text
business_id = UUID
product_id = UUID
customer_id = UUID
sale_id = UUID
```

Benefits:

- Stable identity
- Easier backup/restore
- Easier cloud integration
- Safer future data migration
- Lower collision risk
- No dependency on database-specific auto-increment behavior

The final Dart representation will be selected during Drift implementation.

---

# 6. ID Rules

IDs must:

- Be unique
- Remain stable for the lifetime of the record
- Never be reused
- Never be changed after creation

A deleted/deactivated record must not cause its identifier to become available for reuse.

---

# 7. Business Table

Logical entity:

```text
Business
```

Core fields:

```text
id
name
business_type
phone
address
currency_code
status
created_at
updated_at
```

### Rules

- `id` is the primary key.
- `currency_code` defines the business's default currency.
- Business status controls whether the business is active.
- Business identity must remain stable.

---

# 8. User Table

Logical entity:

```text
User
```

Core fields:

```text
id
business_id
name
username/email
password/authentication reference
role
status
created_at
updated_at
```

### Relationship

```text
Business 1 ──── N Users
```

A user belongs to an authorized business context.

Authentication credentials should not be stored in insecure plain text.

Password hashing/authentication implementation is outside this document.

---

# 9. Category Table

Logical entity:

```text
Category
```

Core fields:

```text
id
business_id
name
description
is_active
created_at
updated_at
```

Relationship:

```text
Business 1 ──── N Categories
Category 1 ──── N Products
```

Category names should normally be unique within a business where practical.

---

# 10. Product Table

Logical entity:

```text
Product
```

Core fields:

```text
id
business_id
category_id
name
sku
barcode
purchase_price
selling_price
unit
minimum_stock
is_active
created_at
updated_at
```

Additional product attributes may be added later if required.

---

# 11. Product Money Fields

Money must never be stored as floating-point values.

For example:

```text
PKR 150.50
```

should conceptually be stored as:

```text
15050
```

where the value represents paisa.

Therefore:

```text
purchase_price_minor
selling_price_minor
```

are preferred logical names.

The currency is determined by the business configuration unless a future requirement introduces multi-currency transactions.

---

# 12. Product Stock

Current stock may be stored as a cached/derived value for fast POS operation.

However, stock changes must also be represented by inventory movements.

Conceptually:

```text
Product.current_stock
```

is a convenient current-state value.

While:

```text
InventoryMovement
```

is the historical explanation of how stock changed.

The system must prevent these two representations from silently diverging.

---

# 13. Customer Table

Logical entity:

```text
Customer
```

Core fields:

```text
id
business_id
name
phone
address
notes
is_active
created_at
updated_at
```

Relationship:

```text
Business 1 ──── N Customers
Customer 1 ──── N Sales
Customer 1 ──── N Payments
Customer 1 ──── N LedgerEntries
```

A customer may exist without ever having a credit balance.

---

# 14. Sale Table

Logical entity:

```text
Sale
```

Core fields:

```text
id
business_id
customer_id
sale_number
sale_datetime
subtotal_minor
discount_minor
total_minor
payment_status
status
created_by
created_at
updated_at
```

`customer_id` may be nullable for a normal anonymous cash sale.

---

# 15. Sale Number

The application should provide a human-readable sale number.

Example:

```text
SALE-000001
SALE-000002
SALE-000003
```

The sale number is different from the internal primary key.

Conceptually:

```text
id
```

is the technical identity.

While:

```text
sale_number
```

is the human-facing business reference.

The exact numbering strategy will be finalized during implementation.

---

# 16. SaleItem Table

Logical entity:

```text
SaleItem
```

Core fields:

```text
id
sale_id
product_id
product_name_snapshot
quantity
unit_price_minor
discount_minor
line_total_minor
created_at
```

Relationship:

```text
Sale 1 ──── N SaleItems
Product 1 ──── N SaleItems
```

---

# 17. Historical Product Snapshot

Sale items should preserve enough product information to remain understandable after product changes.

At minimum, the historical sale should preserve:

```text
product_id
product_name_snapshot
unit_price_minor
quantity
```

Why?

Suppose:

```text
Today:
Product = Coca Cola
Price = PKR 150
```

A sale is completed.

Later:

```text
Product renamed
Price = PKR 180
```

The old sale must still display the historical information correctly.

---

# 18. Quantity Representation

Quantity must not automatically be assumed to be an integer.

Some businesses may sell:

```text
1 piece
2 pieces
1.5 kg
0.75 kg
```

Therefore the data model must support the required precision.

The exact representation will be selected during Drift implementation.

For example, a controlled scaled-integer representation may be used:

```text
1.500 kg
=
1500 units at scale 1000
```

The important requirement is:

**Do not use uncontrolled floating-point arithmetic for quantities that affect financial calculations.**

---

# 19. Payment Table

Logical entity:

```text
Payment
```

Core fields:

```text
id
business_id
customer_id
sale_id
amount_minor
payment_method
payment_datetime
reference
created_by
status
created_at
```

Relationships:

```text
Business 1 ──── N Payments
Customer 1 ──── N Payments
Sale 1 ──── N Payments
```

`sale_id` may be nullable for later customer payments that are not directly tied to one particular sale.

---

# 20. Payment Status

Conceptual states:

```text
ACTIVE
REVERSED
```

A reversed payment remains historically visible.

The original payment should not simply disappear.

---

# 21. LedgerEntry Table

Logical entity:

```text
LedgerEntry
```

Core fields:

```text
id
business_id
customer_id
reference_type
reference_id
entry_type
amount_minor
direction
entry_datetime
description
created_by
created_at
```

Relationship:

```text
Customer 1 ──── N LedgerEntries
```

Ledger entries provide an auditable financial history.

---

# 22. Ledger Direction

The logical model should distinguish between increases and decreases.

For example:

```text
DEBIT
CREDIT
```

or an equivalent domain representation.

The exact terminology will be standardized during implementation.

The important requirement is that the financial effect is unambiguous.

---

# 23. InventoryMovement Table

Logical entity:

```text
InventoryMovement
```

Core fields:

```text
id
business_id
product_id
movement_type
quantity
reference_type
reference_id
movement_datetime
reason
created_by
created_at
```

Relationship:

```text
Product 1 ──── N InventoryMovements
```

---

# 24. Inventory Movement Types

Initial logical types:

```text
SALE
PURCHASE
CUSTOMER_RETURN
ADJUSTMENT_IN
ADJUSTMENT_OUT
DAMAGE
CORRECTION
```

The list may be expanded later through an approved domain change.

---

# 25. Inventory References

An inventory movement should identify why it happened.

Example:

```text
movement_type = SALE
reference_type = SALE
reference_id = <sale-id>
```

Another example:

```text
movement_type = ADJUSTMENT_OUT
reference_type = INVENTORY_ADJUSTMENT
reference_id = <adjustment-id>
```

This makes inventory history explainable.

---

# 26. Expense Table

Logical entity:

```text
Expense
```

Core fields:

```text
id
business_id
category
amount_minor
description
expense_datetime
payment_method
created_by
created_at
updated_at
```

Expenses belong to the business.

They may later support more detailed expense categories.

---

# 27. AuditEvent Table

Logical entity:

```text
AuditEvent
```

Core fields:

```text
id
business_id
user_id
action
entity_type
entity_id
metadata
event_datetime
created_at
```

Audit events record important actions.

Examples:

```text
SALE_CREATED
SALE_CANCELLED
PAYMENT_CREATED
PAYMENT_REVERSED
INVENTORY_ADJUSTED
PRODUCT_PRICE_CHANGED
BACKUP_CREATED
BACKUP_RESTORED
USER_PERMISSION_CHANGED
```

---

# 28. Soft Deletion

Financially relevant records should generally not be physically deleted.

Instead, applicable entities should support a status such as:

```text
is_active
```

or:

```text
status
```

Examples:

```text
Product → inactive
Customer → inactive
Category → inactive
User → inactive
```

Historical transactions should remain intact.

---

# 29. Hard Deletion

Hard deletion should be restricted to records where removal cannot damage historical integrity.

Examples may include:

- Unused configuration records
- Temporary data
- Non-business setup data

Before allowing hard deletion, the application must verify that no protected historical record depends on the entity.

---

# 30. Foreign-Key Relationships

Logical relationships include:

```text
Business
   │
   ├── Users
   ├── Categories
   ├── Products
   ├── Customers
   ├── Sales
   ├── Payments
   ├── LedgerEntries
   ├── InventoryMovements
   ├── Expenses
   └── AuditEvents
```

Specific relationships:

```text
Category → Product
Customer → Sale
Sale → SaleItem
Product → SaleItem
Customer → Payment
Sale → Payment
Customer → LedgerEntry
Product → InventoryMovement
User → Sale
User → Payment
User → InventoryMovement
User → Expense
User → AuditEvent
```

---

# 31. Referential Integrity

Where a relationship is required, the database should enforce referential integrity.

Example:

A SaleItem must reference an existing Sale.

A SaleItem may reference a Product that is later inactive, because historical sales must remain valid.

Therefore historical records must not depend on the continued active status of referenced master data.

---

# 32. Delete Behavior

Delete behavior must be chosen carefully.

For example:

```text
Deleting Product
```

must not cascade into:

```text
SaleItems
InventoryMovements
```

because that would destroy historical information.

Therefore financial and historical records should generally prevent destructive cascading deletes.

---

# 33. Indexing Strategy

Indexes will be required for high-frequency queries.

Important logical indexes include:

### Business ownership

```text
business_id
```

### Product lookup

```text
business_id + sku
business_id + barcode
business_id + name
```

### Customer lookup

```text
business_id + name
business_id + phone
```

### Sales

```text
business_id + sale_datetime
business_id + customer_id
business_id + sale_number
```

### Payments

```text
business_id + payment_datetime
business_id + customer_id
business_id + sale_id
```

### Inventory

```text
business_id + product_id
business_id + movement_datetime
```

### Audit

```text
business_id + event_datetime
business_id + entity_type + entity_id
```

Exact indexes will be finalized after query patterns are defined.

---

# 34. Uniqueness Rules

Uniqueness should generally be scoped to the business.

For example:

```text
business_id + SKU
```

rather than globally unique SKU.

This allows two independent businesses to use the same SKU.

Example:

```text
Business A:
SKU = COKE-001

Business B:
SKU = COKE-001
```

Both are valid.

---

# 35. Nullability Rules

Nullable fields should represent a real business possibility.

Examples:

```text
Sale.customer_id
```

may be nullable because anonymous cash sales are allowed.

However:

```text
Sale.business_id
SaleItem.sale_id
SaleItem.product_id
```

should not normally be nullable.

Avoid nullable fields merely because they make implementation easier.

---

# 36. Timestamp Rules

Persistent records should contain appropriate timestamps.

Common fields:

```text
created_at
updated_at
```

Transactional entities should additionally have their business/event timestamp:

```text
sale_datetime
payment_datetime
movement_datetime
expense_datetime
event_datetime
```

These are conceptually different.

For example:

```text
created_at
```

answers:

> When was this database record created?

while:

```text
sale_datetime
```

answers:

> When did the sale occur?

---

# 37. Money Integrity

Money fields must satisfy:

```text
amount >= 0
```

for ordinary positive amounts.

Negative financial effects should be represented through explicit domain operations where appropriate rather than allowing arbitrary negative values everywhere.

Examples:

```text
Payment
```

normally stores a positive amount.

A reversal is represented through a controlled reversal mechanism.

This prevents accidental negative payments from corrupting balances.

---

# 38. Sale Calculation Integrity

The application should calculate sale totals deterministically.

Conceptually:

```text
Line Total
=
Quantity × Unit Price
-
Line Discount
```

Then:

```text
Subtotal
=
Sum of Line Totals
```

Then:

```text
Total
=
Subtotal
-
Sale Discount
+
Applicable Charges
```

The exact pricing rules will be finalized before the POS implementation.

---

# 39. Atomic Sale Transaction

Creating a completed sale must occur within one database transaction.

Conceptually:

```text
BEGIN TRANSACTION

Create Sale
Create SaleItems
Create Payment(s)
Create LedgerEntries
Create InventoryMovements
Update required current-state values

COMMIT
```

If any required operation fails:

```text
ROLLBACK
```

The application must not leave partially completed financial transactions.

---

# 40. Atomic Customer Payment

Recording a customer payment should be atomic.

Conceptually:

```text
BEGIN TRANSACTION

Create Payment
Create LedgerEntry
Update required balance/cache

COMMIT
```

If one critical operation fails:

```text
ROLLBACK
```

---

# 41. Atomic Inventory Adjustment

Inventory adjustment should also be atomic.

Conceptually:

```text
BEGIN TRANSACTION

Create adjustment record/movement
Update current stock if maintained

COMMIT
```

Failure must roll back the complete operation.

---

# 42. Current-State vs Historical Data

The database contains two categories of information.

### Current state

Examples:

```text
Product.current_stock
Product.selling_price
Customer.active
User.status
```

### Historical events

Examples:

```text
Sale
Payment
LedgerEntry
InventoryMovement
AuditEvent
```

Historical events are the explanation of how the current state came to exist.

The system must avoid creating conflicting independent sources of truth.

---

# 43. Customer Balance Strategy

Customer balance may be calculated from ledger history.

However, because POS applications require fast display, a cached balance may later be introduced.

If a cached balance is used:

```text
Ledger history
      ↓
Authoritative financial state

Cached balance
      ↓
Performance optimization
```

The cache must be repairable/recalculable from authoritative data.

The cached balance must never become an unexplained manually editable number.

---

# 44. Product Stock Strategy

The same principle applies to inventory.

Conceptually:

```text
Inventory movements
       ↓
Authoritative stock history

Current stock
       ↓
Fast current-state representation
```

The system should provide a way to validate/recalculate stock when necessary.

---

# 45. Backup Compatibility

The data model should support reliable backup and restore.

A backup must preserve:

- Business identity
- Product identity
- Customer identity
- Sale identity
- Payment history
- Inventory history
- Ledger history
- Audit history
- Relationships between records

IDs must therefore remain stable across backup and restore.

---

# 46. Migration Strategy

The database schema will evolve over time.

Schema changes must use explicit migrations.

Examples:

```text
Migration 001
Migration 002
Migration 003
```

Never rely on silently changing production schemas.

Every schema change must be:

- Versioned
- Tested
- Reversible where practical
- Safe for existing business data

---

# 47. SQLite/Drift Requirements

The local database must be designed specifically for SQLite constraints.

Important considerations include:

- Foreign-key enforcement
- Transactions
- Indexes
- Migration handling
- Connection lifecycle
- Database locking
- Concurrent access
- Windows file-system behavior
- Backup safety

Drift will be the application-facing database layer.

Business logic must not be scattered throughout raw SQL calls.

---

# 48. Repository Boundary

Features should not directly manipulate the database from UI widgets.

Preferred architecture:

```text
UI
 ↓
Application Service
 ↓
Repository
 ↓
Drift
 ↓
SQLite
```

Example:

```text
SalesPage
    ↓
CreateSaleService
    ↓
SalesRepository
    ↓
Drift Database
```

This keeps UI code independent from persistence details.

---

# 49. Database Does Not Define Business Logic

The database provides:

- Persistence
- Constraints
- Relationships
- Transactions
- Querying

Application/domain services provide:

- Sale rules
- Pricing rules
- Credit rules
- Inventory rules
- Payment rules
- Authorization decisions

Business rules must not be hidden entirely inside UI widgets.

---

# 50. V1 Logical Entity List

The initial persistent model is:

```text
01 Business
02 User
03 Category
04 Product
05 Customer
06 Sale
07 SaleItem
08 Payment
09 LedgerEntry
10 InventoryMovement
11 Expense
12 AuditEvent
```

Additional entities may be introduced only when a real V1 requirement requires them.

Avoid creating speculative tables for future features.

---

# 51. Explicit V1 Exclusions

The data model does not currently include dedicated entities for:

- Mobile devices
- Sync queues
- Sync conflicts
- Device registration for bidirectional synchronization
- Multi-device synchronization
- Offline operation queues
- Remote mobile replicas
- Full accounting journals
- Payroll
- Manufacturing
- E-commerce orders
- Delivery routes
- Warehouse transfers
- Multi-store operations

These may be future architecture extensions.

They are intentionally excluded from V1.

---

# 52. Database Design Gate

Before creating Drift tables, the following must be approved:

- Entity list
- Primary-key strategy
- Business ownership
- Money representation
- Quantity representation
- Relationships
- Delete behavior
- Status strategy
- Timestamp strategy
- Index strategy
- Transaction boundaries
- Migration strategy

Only after this gate is complete should the physical Drift schema be implemented.

---

# 53. Next Step

After approval of this data model:

```text
Data Model
     ↓
Drift Table Design
     ↓
Database Connection
     ↓
Initial Migration
     ↓
Database Tests
     ↓
Repositories
```

The next implementation artifact will define the actual Drift tables and database configuration.

No feature UI should be connected to the database until the database foundation has passed its tests.