Advanced SQL Retail Analytics

Overview
This project demonstrates end-to-end relational database design and SQL analytics using the Brazilian Olist E-commerce dataset. The project includes database schema design, implementation of primary and foreign key relationships, data validation, and analytical SQL queries to extract business insights from retail transactions. 
The objective is to simulate a real-world retail analytics workflow by transforming raw transactional data into a structured relational database and answering common business questions through SQL.

Dataset
Source: Brazilian E-Commerce Public Dataset by Olist
The dataset contains anonymized information on customer orders placed through the Olist marketplace, including customers, products, sellers, payments, reviews, and delivery information.
The following tables are included:
Customers
Orders
Order Items
Products
Sellers
Order Payments
Order Reviews
Product Category Translation
Geolocation

Project Structure
olist-sql-retail-analytics/
│

├── README.md

├── .gitignore

│

├── data/

│   ├── customers_sample.csv

│   ├── orders_sample.csv

│   ├── order_items_sample.csv

│   ├── products_sample.csv

│   └── payments_sample.csv

│

├── sql/

│   ├── schema.sql

│   └── analysis.sql

│

└── diagrams/
   
    └── olist_erd.png
    
Database Schema
The relational database consists of the following entities:
Customers
Orders
Order Items
Products
Sellers
Payments
Reviews
Product Category Translation
Geolocation
The database has been normalized and implemented using primary keys, foreign keys, integrity constraints, and indexes.

Technologies Used
PostgreSQL
SQL
Power BI (ER Diagram)
Git
GitHub
SQL Topics Demonstrated

This project demonstrates practical use of:
Database schema design
Primary and foreign keys
Data integrity constraints
INNER, LEFT and FULL JOINs
Aggregate functions
GROUP BY and HAVING
CASE expressions
Common Table Expressions (CTEs)
Subqueries
Window Functions
Ranking functions
Views
Data validation queries
Business KPI reporting
Business Analysis Performed

The SQL queries answer business questions related to:
Sales performance
Revenue analysis
Customer analytics
Customer Lifetime Value (CLV)
Repeat purchase analysis
RFM customer segmentation
Product performance
Category performance
Seller performance
Payment behaviour
Delivery performance
Customer review analysis
Geographic sales analysis
Monthly sales trends
Executive KPI dashboard queries
Key Database Relationships
Customer → Orders
Orders → Order Items
Orders → Payments
Orders → Reviews
Products → Order Items
Sellers → Order Items
Product Categories → Products
How to Run
Create a PostgreSQL database.
Execute sql/schema.sql to create all tables and constraints.
Import the sample CSV files into their corresponding tables.
Execute the queries in sql/analysis.sql.
Sample Business Questions

The project answers questions such as:
What is the total revenue generated?
Which product categories generate the highest sales?
Which sellers contribute the most revenue?
What is the average order value?
Which customers have the highest lifetime value?
What percentage of customers are repeat buyers?
How do monthly sales change over time?
Which payment methods are most frequently used?
Which states generate the highest revenue?
How does delivery performance affect customer review scores?

Future Improvements 
Possible extensions include:
ETL automation using Python
Power BI dashboard development
Customer churn prediction
Sales forecasting
Data warehouse implementation
Azure Data Factory integration
Apache Airflow workflow orchestration

Author
Antonita Joseph
MSc Marketing Analytics and Data Intelligence
