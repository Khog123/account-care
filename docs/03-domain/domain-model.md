# Account Care V1 — Domain Model

**Status:** Approved for V1 architecture  
**Product:** Account Care Commercial Desktop V1  
**Platform:** Windows Desktop  
**Database:** Local SQLite via Drift  
**Cloud:** Optional encrypted backup and future remote read-only access

---

## 1. Purpose

This document defines the business/domain model for Account Care V1.

It describes:

- Core business entities
- Relationships between entities
- Financial rules
- Inventory rules
- Customer and credit rules
- Payment rules
- Transaction correction rules
- Deletion rules
- Audit requirements
- Tenant/business ownership

This document defines the **domain model**, not the physical database schema.

The Drift tables, indexes, foreign keys, migrations, and database-specific implementation will be designed later from this model.

---

# 2. Core Architecture Principles

Account Care follows these principles:

### 2.1 Local-first operation

The desktop application must continue normal business operations without an internet connection.

The following must work offline:

- Creating sales
- Creating credit sales
- Recording payments
- Managing products
- Managing inventory
- Managing customers
- Viewing reports
- Printing receipts
- Creating local backups

Cloud services must not be required for normal daily sales.

---

### 2.2 Business ownership

Every commercial record belongs to a specific business.

The primary business ownership boundary is:

```text
Business
    ↓
Business-owned records
```

Examples:

- Products
- Categories
- Customers
- Sales
- Sale items
- Payments
- Ledger entries
- Inventory movements
- Expenses
- Users
- Audit events

A record belonging to Business A must never be accessible to Business B.

---

### 2.3 Financial integrity

Financial records must be accurate and traceable.

Historical financial transactions should not normally be overwritten or silently deleted.

Corrections should be represented through controlled operations such as:

- Payment reversal
- Sale return
- Inventory adjustment
- Transaction correction
- Cancellation
- Audit event

---

### 2.4 Exact money representation

Money must not use floating-point values for financial calculations.

The domain layer should represent monetary values using integer minor units.

For PKR:

```text
PKR 150.50
=
15050 paisa
```

Therefore:

```text
amount = 15050
currency = PKR
```

The UI may display:

```text
PKR 150.50
```

but calculations must use exact values.

---

# 3. Core Entities

Account Care V1 contains the following primary domain entities:

1. Business
2. User
3. Category
4. Product
5. Customer
6. Sale
7. SaleItem
8. Payment
9. LedgerEntry
10. InventoryMovement
11. Expense
12. AuditEvent

---

# 4. Business

## Purpose

Represents the merchant/business using Account Care.

A business is the primary tenant boundary.

## Important attributes

Conceptually:

```text
Business
- id
- name
- business type
- owner information
- phone
- address
- currency
- created date
- status
```

The exact physical fields will be finalized during database design.

## Rules

- Every business has a unique identifier.
- Business data must remain isolated from other businesses.
- A business may have multiple authorized users.
- V1 primarily targets one physical store per business.
- The architecture should not prevent future multi-store support.

---

# 5. User

## Purpose

Represents a person authorized to use Account Care for a business.

Examples:

- Business owner
- Master merchant
- Store clerk
- Manager

## Relationships

```text
Business
   |
   └── Users
```

## Rules

- A user must belong to an authorized business context.
- User permissions determine which operations they may perform.
- Authentication and authorization are separate concerns.
- A client must never be trusted to determine its own business authorization.
- Sensitive actions should be auditable.

---

# 6. Category

## Purpose

Groups products for organization and reporting.

Examples:

```text
Beverages
Snacks
Grocery
Personal Care
Stationery
```

## Relationships

```text
Business
   |
   └── Categories
           |
           └── Products
```

## Rules

- A category belongs to one business.
- A category may contain many products.
- A category should not be hard-deleted if historical reporting depends on it.
- If a category is no longer required, it should normally be deactivated/archived.

---

# 7. Product

## Purpose

Represents an item that can be purchased, sold, and tracked in inventory.

Examples:

```text
Coca Cola 1.5L
Sugar 1kg
Surf Excel 500g
Bread
```

## Conceptual attributes

```text
Product
- id
- business_id
- category_id
- name
- SKU/barcode
- purchase price
- selling price
- current stock
- minimum stock level
- unit
- active status
- created date
- updated date
```

The exact physical representation of stock and prices will be finalized during database design.

## Rules

- Product belongs to one business.
- Product may optionally belong to a category.
- Product can be sold only when active.
- Product price changes must not rewrite historical sale prices.
- Historical SaleItems retain the price used at the time of sale.
- Product deletion should normally mean deactivation/archive rather than physical deletion when historical records exist.

---

# 8. Customer

## Purpose

Represents a customer.

Customers are especially important for credit/Udhaar transactions.

## Conceptual attributes

```text
Customer
- id
- business_id
- name
- phone
- address
- notes
- active status
- created date
- updated date
```

## Rules

- Customer belongs to one business.
- Customer may have many sales.
- Customer may have many payments.
- Customer may have a running outstanding balance.
- Customer information may be updated without modifying historical transactions.
- Historical transactions retain their original financial values.

---

# 9. Sale

## Purpose

Represents a completed or controlled sales transaction.

A sale is the main financial transaction in the POS.

## Conceptual relationship

```text
Customer
    |
    └── Sale
          |
          ├── SaleItem
          ├── Payment
          └── LedgerEntry
```

A sale may be:

- Cash sale
- Credit/Udhaar sale
- Partially paid sale

## Conceptual attributes

```text
Sale
- id
- business_id
- customer_id (optional for cash sale)
- sale number
- sale date/time
- subtotal
- discount
- total
- payment status
- sale status
- created by
- created date
```

## Sale status

Possible conceptual states:

```text
COMPLETED
CANCELLED
RETURNED
PARTIALLY_RETURNED
```

The exact enum design will be finalized later.

## Rules

### Sale total

Conceptually:

```text
Subtotal
- Discount
+ applicable charges
= Total
```

The exact pricing rules will be defined separately.

### Historical price

A sale must store the actual price used at the time of sale.

Example:

```text
Product current price = PKR 200
```

A previous sale may have used:

```text
PKR 180
```

Changing the product price to PKR 200 must not change the historical sale.

---

# 10. SaleItem

## Purpose

Represents an individual product line within a sale.

Example:

```text
Sale #1001

Coca Cola     2 × 150 = 300
Bread         1 × 120 = 120
-------------------------
Total                  420
```

The SaleItem represents each line.

## Conceptual attributes

```text
SaleItem
- id
- sale_id
- product_id
- product name snapshot
- quantity
- unit price
- discount
- line total
```

## Important rule

SaleItem must preserve the financial information used during the original transaction.

Product information can change later, but historical sale information must remain understandable.

---

# 11. Payment

## Purpose

Represents money received from a customer.

Payments may occur:

- At the time of sale
- Later against an outstanding credit balance
- As multiple partial payments

Example:

```text
Sale total:       PKR 10,000
Paid immediately: PKR 4,000
Outstanding:      PKR 6,000
```

Later:

```text
Payment: PKR 2,000
Remaining: PKR 4,000
```

## Conceptual attributes

```text
Payment
- id
- business_id
- customer_id
- sale_id (optional)
- amount
- payment method
- payment date/time
- reference
- created by
```

## Payment methods

Initial conceptual methods may include:

```text
CASH
BANK
CARD
OTHER
```

The exact list may be expanded later.

## Rules

- Payment amount must be greater than zero.
- Payment cannot silently exceed the allowed outstanding amount unless the business rules explicitly support advance payments.
- Every payment must be traceable.
- A payment reversal should be represented as a controlled reversal rather than silently modifying history.

---

# 12. LedgerEntry

## Purpose

Represents the accounting/business effect of financial events.

The ledger provides a traceable history of changes affecting customer balances and other financial records.

Example:

```text
Credit Sale      + PKR 5,000
Payment          - PKR 2,000
---------------------------
Outstanding      PKR 3,000
```

## Conceptual attributes

```text
LedgerEntry
- id
- business_id
- customer_id
- reference type
- reference id
- entry type
- amount
- direction
- date/time
- description
```

## Important rule

The ledger should be treated as an auditable financial history.

Do not simply overwrite old ledger entries to make a balance look correct.

Corrections should create appropriate compensating/reversal entries.

---

# 13. Customer Balance

Customer balance is conceptually derived from financial transactions.

For a basic credit model:

```text
Outstanding Balance
=
Credit Sales
-
Customer Payments
-
Valid Returns/Credits
+
Applicable Adjustments
```

The implementation may maintain a cached balance for performance, but the system must have a reliable source of truth from transaction history.

A cached balance must never become an uncontrolled independent financial value.

---

# 14. InventoryMovement

## Purpose

Represents every meaningful change to product stock.

Examples:

```text
Sale
Purchase
Return
Manual Adjustment
Damage
Correction
```

## Conceptual attributes

```text
InventoryMovement
- id
- business_id
- product_id
- movement type
- quantity
- reference type
- reference id
- date/time
- created by
- reason
```

## Movement types

Conceptually:

```text
SALE
PURCHASE
CUSTOMER_RETURN
ADJUSTMENT_IN
ADJUSTMENT_OUT
DAMAGE
CORRECTION
```

The final list will be decided during implementation.

---

# 15. Inventory Rules

Inventory must be traceable.

A sale should not simply change:

```text
product.stock = product.stock - quantity
```

without recording why the stock changed.

Instead:

```text
Sale
  ↓
InventoryMovement
  ↓
Stock effect
```

Example:

```text
Opening stock: 100

Sale: -3

Current stock: 97
```

The movement history records the reason.

## Historical integrity

If an inventory mistake is discovered:

Do not rewrite the original movement.

Create an adjustment/correction movement.

Example:

```text
Original:
Sale = -10

Correction:
Adjustment = +2
```

This preserves history.

---

# 16. Expense

## Purpose

Represents business expenses.

Examples:

```text
Electricity
Shop rent
Transportation
Packaging
Maintenance
Other expenses
```

## Conceptual attributes

```text
Expense
- id
- business_id
- category
- amount
- description
- date/time
- payment method
- created by
```

Expenses are used by reporting to calculate business profitability.

---

# 17. AuditEvent

## Purpose

Records important actions performed in the system.

Audit events are especially important for commercial and financial software.

Examples:

```text
User logged in
Product price changed
Sale cancelled
Payment recorded
Payment reversed
Inventory adjusted
Backup created
Backup restored
User permission changed
```

## Conceptual attributes

```text
AuditEvent
- id
- business_id
- user_id
- action
- entity type
- entity id
- timestamp
- metadata
```

## Rules

Audit events should provide enough information to answer:

```text
Who?
What?
When?
Which record?
What happened?
```

Audit records should not be casually deleted from normal application workflows.

---

# 18. Core Relationships

The high-level relationship model is:

```text
Business
│
├── Users
│
├── Categories
│      │
│      └── Products
│
├── Customers
│      │
│      ├── Sales
│      │     └── SaleItems
│      │
│      ├── Payments
│      │
│      └── LedgerEntries
│
├── Products
│      │
│      └── InventoryMovements
│
├── Expenses
│
└── AuditEvents
```

A more detailed transaction relationship:

```text
                    ┌──────────────┐
                    │   Customer   │
                    └──────┬───────┘
                           │
                           │
                    ┌──────▼───────┐
                    │     Sale     │
                    └──────┬───────┘
                           │
                 ┌─────────┴─────────┐
                 │                   │
          ┌──────▼──────┐     ┌──────▼─────────┐
          │  SaleItems  │     │    Payment     │
          └──────┬──────┘     └────────────────┘
                 │
                 │
          ┌──────▼────────────┐
          │ InventoryMovement │
          └───────────────────┘

                    Sale
                     │
                     ▼
               LedgerEntry
```

---

# 19. Complete Sale Transaction

A completed sale is a coordinated business operation.

Conceptually:

```text
Create Sale
    ↓
Create Sale Items
    ↓
Calculate totals
    ↓
Record payment
    ↓
Update customer financial position
    ↓
Create ledger entries
    ↓
Create inventory movements
    ↓
Complete transaction
```

These operations must behave as one atomic transaction at the database level.

If any critical step fails:

```text
The entire sale operation must be rolled back.
```

The system must never produce a situation such as:

```text
Sale exists
BUT
inventory was not reduced
```

or:

```text
Payment exists
BUT
customer ledger was not updated
```

---

# 20. Cash Sale

Example:

```text
Sale total = PKR 1,000
Customer pays = PKR 1,000
```

Result:

```text
Sale = completed
Payment = PKR 1,000
Customer outstanding = unchanged
Inventory = reduced
Ledger = appropriate transaction history
```

---

# 21. Credit/Udhaar Sale

Example:

```text
Sale total = PKR 5,000
Payment = PKR 0
```

Result:

```text
Sale = completed
Payment = PKR 0
Customer outstanding = +PKR 5,000
Inventory = reduced
Ledger = credit sale entry
```

---

# 22. Partially Paid Sale

Example:

```text
Sale total = PKR 5,000
Paid = PKR 2,000
Credit = PKR 3,000
```

Result:

```text
Sale = completed
Payment = PKR 2,000
Outstanding = PKR 3,000
Inventory = reduced
Ledger = appropriate entries
```

---

# 23. Later Customer Payment

Example:

```text
Existing balance = PKR 3,000
Customer pays = PKR 1,000
```

Result:

```text
Payment recorded = PKR 1,000
Remaining balance = PKR 2,000
Ledger records payment
```

The original sale is not modified.

---

# 24. Sale Return

Returns must preserve the original sale.

Do not delete the original sale.

Conceptually:

```text
Original Sale
     ↓
Return transaction
     ↓
Inventory returned
     ↓
Customer financial position adjusted
```

Example:

```text
Original sale:
2 × Product A

Customer returns:
1 × Product A
```

The system should create a return/correction event rather than rewriting the original sale.

The exact return entity/model will be finalized before implementing return functionality.

---

# 25. Payment Reversal

If a payment was entered incorrectly:

Do not simply delete it if it has already affected financial history.

Instead:

```text
Original Payment
      ↓
Payment Reversal
```

This preserves the audit trail.

Example:

```text
Payment:
PKR 5,000

Reversal:
PKR -5,000

Net effect:
PKR 0
```

The exact implementation will be defined during financial-domain implementation.

---

# 26. Product Price Changes

Changing a product price affects future sales only.

Example:

```text
Old selling price = PKR 100

Sale A = PKR 100
```

Later:

```text
New selling price = PKR 120
```

Historical Sale A remains:

```text
PKR 100
```

Future sales use:

```text
PKR 120
```

---

# 27. Product Deletion

Products should generally not be physically deleted once they have historical transactions.

Instead:

```text
Product.active = false
```

or equivalent archival behavior.

The product remains available for:

- Historical sales
- Reports
- Inventory history
- Audit
- Returns/corrections

---

# 28. Customer Deletion

Customers with historical financial transactions should not be physically deleted.

Instead:

```text
Customer.active = false
```

Historical records remain accessible.

This prevents financial history from becoming disconnected.

---

# 29. Category Deletion

Categories should normally be archived/deactivated if products or historical data depend on them.

Deleting a category must not delete its products or historical transactions.

---

# 30. Financial Corrections

Account Care must prefer traceable corrections over destructive edits.

Examples:

### Incorrect sale

Use:

```text
Cancellation / reversal / return
```

rather than silently changing historical financial values.

### Incorrect payment

Use:

```text
Payment reversal
```

### Incorrect inventory

Use:

```text
Inventory adjustment
```

### Incorrect customer balance

Investigate the underlying transactions and correct the source transaction rather than manually overwriting the balance without an audit trail.

---

# 31. Business Isolation

Every business-owned record must be associated with the correct business.

Conceptually:

```text
Business A
 ├── Products
 ├── Customers
 ├── Sales
 ├── Payments
 └── Reports

Business B
 ├── Products
 ├── Customers
 ├── Sales
 ├── Payments
 └── Reports
```

Business A must never see Business B's records.

This applies to:

- Local application queries
- Cloud backup metadata
- Backend APIs
- Remote reporting
- User authorization
- Audit records

Tenant isolation is a security requirement, not merely a filtering convention.

---

# 32. Money and Currency Rules

The application must define a business currency.

V1 will primarily target currencies such as:

```text
PKR
USD
INR
SAR
```

Money calculations must use exact representations.

Do not use:

```text
double
```

for financial calculations.

Use an exact integer minor-unit representation or another exact monetary representation approved during database design.

---

# 33. Date and Time Rules

Transactions must record their creation/business date and time.

Financial records should not depend only on the computer's current display formatting.

The system should establish a consistent strategy for:

- Local business time
- Storage format
- Reporting date
- Backup timestamps
- Audit timestamps

The exact implementation will be finalized during application infrastructure design.

---

# 34. Reporting Dependencies

Reports should be derived from authoritative business records.

Important reports include:

### Sales

- Daily sales
- Monthly sales
- Sales by product
- Sales by customer
- Sales by payment method

### Profit

Conceptually:

```text
Sales Revenue
-
Cost of Goods Sold
-
Expenses
=
Profit
```

The exact profit calculation will be finalized when purchase/cost tracking is fully defined.

### Credit/Udhaar

- Total outstanding
- Customer balances
- Payment history
- Credit sales
- Collection history

### Inventory

- Current stock
- Low stock
- Stock movement
- Sales by product
- Adjustments

Reports must not become an independent source of truth.

---

# 35. Backup Domain Rule

Backups are copies of business data.

A backup must not change normal business records.

Cloud backup is optional.

Therefore:

```text
Internet available
    ↓
Optional backup

Internet unavailable
    ↓
Business continues normally
```

A failed cloud backup must not prevent:

- Sales
- Payments
- Inventory operations
- Customer management
- Reports

Local backup remains an independent safety mechanism.

---

# 36. Auditability

Important financial and administrative operations should be traceable.

At minimum, the system should be able to identify:

```text
Who performed the action?
When?
What entity was affected?
What action occurred?
What was the reason where applicable?
```

Audit events are especially important for:

- Sale cancellation
- Sale return
- Payment reversal
- Inventory adjustment
- Product price changes
- User/permission changes
- Backup creation
- Backup restoration

---

# 37. Domain Invariants

The following rules must always hold.

### INV-001 — Business ownership

Every business-owned record belongs to exactly one business.

### INV-002 — Sale integrity

A completed sale must have valid SaleItems.

### INV-003 — Sale total

The stored sale total must equal the result of the defined pricing calculation.

### INV-004 — Sale price history

Historical sale prices must not change when product prices change.

### INV-005 — Inventory traceability

A stock change must have an identifiable reason/source.

### INV-006 — Payment validity

A payment must have a valid positive amount unless explicitly representing a controlled reversal.

### INV-007 — Financial traceability

Historical financial events must not be silently destroyed.

### INV-008 — Customer balance integrity

Customer outstanding balances must be consistent with authoritative financial transactions.

### INV-009 — Tenant isolation

A user must not access another business's records without explicit authorization.

### INV-010 — Atomic financial operations

Critical sale operations must either complete successfully or roll back completely.

### INV-011 — Offline independence

Normal POS operations must not depend on cloud availability.

### INV-012 — Auditability

Important financial and administrative changes must be traceable.

---

# 38. Domain Model vs Database Schema

This document intentionally does **not** define:

- SQL tables
- Drift table classes
- PostgreSQL tables
- Prisma models
- indexes
- migration files
- foreign-key implementation
- SQLite-specific types
- PostgreSQL-specific types

Those decisions will be made after the domain model is approved.

The implementation hierarchy is:

```text
Business Requirements
        ↓
Domain Model
        ↓
Data Model
        ↓
Database Schema
        ↓
Repositories
        ↓
Application Services
        ↓
UI
```

This prevents the database from accidentally defining the business rules.



# 39. V1 Scope Boundary

The following are intentionally outside the current domain model unless later approved:

- Mobile application
- Bidirectional synchronization
- Offline sync queues
- Conflict resolution
- Multi-device live synchronization
- Full accounting/ERP system
- Payroll
- Manufacturing
- E-commerce
- Delivery management
- Complex warehouse management
- Multi-store operations as a V1 workflow

The architecture may leave room for future expansion, but V1 should not implement these features unnecessarily.

---

# 40. Next Architecture Stage

After this domain model is approved, the next stage is:

```text
Domain Model
     ↓
Data Model
     ↓
Drift Database Design
     ↓
Database Migrations
     ↓
Repositories
     ↓
Application Services
     ↓
Business Features
```

The next document should define the **data model and database architecture** before creating the actual Drift tables.

No production database tables should be created until that stage is complete.