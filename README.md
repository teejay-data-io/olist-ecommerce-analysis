# Olist E-commerce Analysis: Behaviour, Retention, Engagement

![Behaviour charts: delivered orders per month and average review score by delivery days](02_Python/behaviour_charts.png)

## Business problem

Why do customers on a Brazilian online marketplace buy once and never come back?

I looked at that question through three lenses:

- **Behaviour**: what people buy, when they buy, and how they pay.
- **Retention**: how many customers come back for a second order.
- **Engagement**: how customers respond after an order. Olist has no clickstream data (no page views or sessions), so here engagement means **reviews and repeat activity**.

## Data & tools

**Data:** the [Olist Brazilian E-commerce public dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle, with orders from 2016 to 2018 across 8 related tables (orders, customers, order items, payments, reviews, products, sellers and a category translation table). I loaded it into MySQL and built one cleaned, single-source table, `orders_clean` (one row per order), so every tool reports the same numbers.

**Tools:**

- **MySQL**: import, cleaning, data quality checks, business questions
- **Python**: pandas, sqlalchemy, matplotlib / seaborn
- **Power BI**: dashboard (in progress)
- **Excel**: what-if scenarios (in progress)

## What I did

### 1. SQL ([01_SQL](01_SQL))
- Imported the 8 tables into MySQL and fixed import issues (empty values turned into NULLs, a hidden BOM character in a column name).
- Checked row counts after every import, then looked for duplicates, missing values and impossible delivery dates.
- Answered business questions on monthly orders and revenue, top categories, payment methods, late deliveries by state, reviews for on-time vs late orders, repeat purchases, freight cost by category and top sellers.
- Built `orders_clean`, the single table that feeds Python, Power BI and Excel.

### 2. Python ([02_Python](02_Python))
- Connected to MySQL with sqlalchemy and pulled `orders_clean` into pandas.
- Charted monthly orders and the link between delivery time and review score (the image above).
- Built a monthly cohort retention analysis to see how many first-time buyers come back in later months.

### 3. Power BI: in progress
A dashboard with one page each for Behaviour, Retention and Engagement, plus a summary page.

### 4. Excel: in progress
A what-if model for margin and freight scenarios.

## Key findings

Headline numbers (delivered orders):

| Metric | Value |
|---|---|
| Delivered orders | 96,478 |
| Customers | 93,358 |
| GMV | 15,422,461.77 |
| Average order value | 159.86 |
| Average review score | 4.16 |
| Orders delivered late | 8.1% |
| Average delivery time | 12.5 days |

**Behaviour**
- Orders grew steadily and peaked in **November 2017 with 7,289 orders**.
- **Credit card** made up **78.3%** of payment value.

**Retention**
- **96.88%** of customers bought only once.
- The Python cohort analysis agrees: **97.0%** bought once, and **under 1%** of customers return in any later month.

**Engagement**
- Late deliveries hurt reviews badly: orders delivered on time average **4.29** stars, late ones only **2.57**.
- Orders delivered in around a week average about **4.5** stars. Once delivery passes **30 days**, the average falls **below 3**.
- Late delivery is worst in **AL (23.9%)** and **MA (19.7%)**.

**Takeaway:** customers are mostly happy (4.16 average rating), yet almost none come back. **This is a retention problem, not a quality problem.**

## Recommendations

1. **Fix late delivery in AL and MA first.** These states have the highest late rates, and late orders get far lower reviews.
2. **Re-engage first-time buyers after delivery.** With about 97% buying only once, a simple follow-up (thank-you message, review request, offer on a second order) targets the biggest gap.
3. **Set honest delivery-time promises.** Ratings drop as delivery time grows, so realistic estimates protect reviews and trust.

## Repo structure

```
olist-ecommerce-analysis/
├── 01_SQL/
│   └── 01_olist_sql_analysis.sql      # import, cleaning, DQ checks, business questions, orders_clean
├── 02_Python/
│   └── behaviour_charts.png           # monthly orders + review score by delivery days
├── 03_PowerBI/                        # Power BI dashboard (in progress)
├── 04_Excel/                          # Excel what-if model (in progress)
└── README.md
```

## About me

I'm **Tajudeen Rabiu**, an accountant moving into e-commerce data analysis. My accounting background means I check the numbers before I report them, and I like turning data into decisions a business can act on.

- LinkedIn: [linkedin.com/in/tajudeen-rabiu-data](https://www.linkedin.com/in/tajudeen-rabiu-data)
- Portfolio: [teejay-data-io.github.io](https://teejay-data-io.github.io/)
