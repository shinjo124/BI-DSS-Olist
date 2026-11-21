SET XACT_ABORT ON;
BEGIN TRANSACTION;
IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg');

CREATE TABLE stg.Orders (
    order_id char(32) NOT NULL PRIMARY KEY,
    customer_id char(32) NOT NULL,
    order_status varchar(30) NOT NULL,
    order_purchase_timestamp datetime2 NOT NULL,
    order_approved_at datetime2 NULL,
    order_delivered_carrier_date datetime2 NULL,
    order_delivered_customer_date datetime2 NULL,
    order_estimated_delivery_date datetime2 NULL
);
CREATE TABLE stg.Customers (
    customer_id char(32) NOT NULL PRIMARY KEY,
    customer_unique_id char(32) NOT NULL,
    customer_zip_code_prefix varchar(10) NOT NULL,
    customer_city nvarchar(100) NOT NULL,
    customer_state varchar(20) NOT NULL
);
CREATE TABLE stg.Products (
    product_id char(32) NOT NULL PRIMARY KEY,
    product_category_name nvarchar(100) NULL,
    product_weight_g int NULL
);
CREATE TABLE stg.CategoryTranslation (
    product_category_name nvarchar(100) NOT NULL PRIMARY KEY,
    product_category_name_english nvarchar(100) NOT NULL
);
CREATE TABLE stg.Sellers (
    seller_id char(32) NOT NULL PRIMARY KEY,
    seller_zip_code_prefix varchar(10) NOT NULL,
    seller_city nvarchar(100) NOT NULL,
    seller_state varchar(20) NOT NULL
);
CREATE TABLE stg.OrderItems (
    order_id char(32) NOT NULL,
    order_item_id int NOT NULL,
    product_id char(32) NOT NULL,
    seller_id char(32) NOT NULL,
    shipping_limit_date datetime2 NOT NULL,
    price decimal(19,2) NOT NULL,
    freight_value decimal(19,2) NOT NULL,
    CONSTRAINT PK_StgOrderItems PRIMARY KEY (order_id, order_item_id)
);
CREATE TABLE stg.Payments (
    order_id char(32) NOT NULL,
    payment_sequential int NOT NULL,
    payment_type varchar(30) NOT NULL,
    payment_installments int NOT NULL,
    payment_value decimal(19,2) NOT NULL,
    CONSTRAINT PK_StgPayments PRIMARY KEY (order_id, payment_sequential)
);
CREATE TABLE stg.Reviews (
    review_id char(32) NOT NULL,
    order_id char(32) NOT NULL,
    review_score tinyint NOT NULL CHECK (review_score BETWEEN 1 AND 5),
    review_creation_date datetime2 NOT NULL,
    review_answer_timestamp datetime2 NOT NULL
);
CREATE INDEX IX_StgReviews_Order ON stg.Reviews (order_id);

COMMIT TRANSACTION;
