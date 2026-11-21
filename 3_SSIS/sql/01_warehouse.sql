SET XACT_ABORT ON;
BEGIN TRANSACTION;

CREATE TABLE dbo.DimDate (
    DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
    FullDate date NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
    [Year] smallint NOT NULL, [Quarter] tinyint NOT NULL, [Month] tinyint NOT NULL,
    [Day] tinyint NOT NULL, MonthName varchar(9) NOT NULL,
    ISOWeekdayNo tinyint NOT NULL, ISOWeekdayName varchar(9) NOT NULL
);
CREATE TABLE dbo.DimCustomer (
    CustomerKey int IDENTITY NOT NULL CONSTRAINT PK_DimCustomer PRIMARY KEY,
    CustomerID char(32) NOT NULL CONSTRAINT UQ_DimCustomer_ID UNIQUE,
    CustomerUniqueID char(32) NOT NULL, City nvarchar(100) NOT NULL,
    [State] varchar(20) NOT NULL, Region varchar(30) NOT NULL
);
CREATE TABLE dbo.DimProduct (
    ProductKey int IDENTITY NOT NULL CONSTRAINT PK_DimProduct PRIMARY KEY,
    ProductID char(32) NOT NULL CONSTRAINT UQ_DimProduct_ID UNIQUE,
    CategoryOriginal nvarchar(100) NOT NULL, CategoryEnglish nvarchar(100) NOT NULL,
    TranslationMissing bit NOT NULL, WeightG int NULL
);
CREATE TABLE dbo.DimSeller (
    SellerKey int IDENTITY NOT NULL CONSTRAINT PK_DimSeller PRIMARY KEY,
    SellerID char(32) NOT NULL CONSTRAINT UQ_DimSeller_ID UNIQUE,
    City nvarchar(100) NOT NULL, [State] varchar(20) NOT NULL, Region varchar(30) NOT NULL
);
CREATE TABLE dbo.DimPayment (
    PaymentKey int IDENTITY NOT NULL CONSTRAINT PK_DimPayment PRIMARY KEY,
    PaymentType varchar(30) NOT NULL CONSTRAINT UQ_DimPayment_Type UNIQUE
);
CREATE TABLE dbo.DimOrder (
    OrderKey int IDENTITY NOT NULL CONSTRAINT PK_DimOrder PRIMARY KEY,
    OrderID char(32) NOT NULL CONSTRAINT UQ_DimOrder_ID UNIQUE
);
CREATE TABLE dbo.FactSales (
    OrderKey int NOT NULL REFERENCES dbo.DimOrder(OrderKey), OrderItemID int NOT NULL,
    DateKey int NOT NULL REFERENCES dbo.DimDate(DateKey),
    CustomerKey int NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
    ProductKey int NOT NULL REFERENCES dbo.DimProduct(ProductKey),
    SellerKey int NOT NULL REFERENCES dbo.DimSeller(SellerKey),
    Quantity int NOT NULL CONSTRAINT CK_FactSales_Quantity CHECK (Quantity = 1),
    Price decimal(19,2) NOT NULL, FreightValue decimal(19,2) NOT NULL,
    CONSTRAINT UQ_FactSales_OrderItem UNIQUE (OrderKey, OrderItemID)
);
CREATE TABLE dbo.FactOrder (
    OrderKey int NOT NULL CONSTRAINT PK_FactOrder PRIMARY KEY REFERENCES dbo.DimOrder(OrderKey),
    DateKey int NOT NULL REFERENCES dbo.DimDate(DateKey),
    CustomerKey int NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
    ReviewID char(32) NULL, ReviewCreationDate datetime2 NULL, ReviewScore tinyint NULL,
    ReviewPresent bit NOT NULL, DeliveryDays int NULL, DeliveredFlag bit NOT NULL,
    LateFlag bit NULL, LateEligibleFlag bit NOT NULL,
    CONSTRAINT CK_FactOrder_Review CHECK ((ReviewPresent = 0 AND ReviewScore IS NULL) OR (ReviewPresent = 1 AND ReviewScore IS NOT NULL AND ReviewScore BETWEEN 1 AND 5)),
    CONSTRAINT CK_FactOrder_Delivery CHECK ((DeliveredFlag = 0 AND DeliveryDays IS NULL) OR (DeliveredFlag = 1 AND DeliveryDays IS NOT NULL)),
    CONSTRAINT CK_FactOrder_Late CHECK ((LateEligibleFlag = 0 AND LateFlag IS NULL) OR (LateEligibleFlag = 1 AND LateFlag IS NOT NULL))
);
CREATE TABLE dbo.FactPayment (
    OrderKey int NOT NULL REFERENCES dbo.DimOrder(OrderKey), PaymentSequential int NOT NULL,
    DateKey int NOT NULL REFERENCES dbo.DimDate(DateKey),
    CustomerKey int NOT NULL REFERENCES dbo.DimCustomer(CustomerKey),
    PaymentKey int NOT NULL REFERENCES dbo.DimPayment(PaymentKey),
    PaymentValue decimal(19,2) NOT NULL, PaymentInstallments int NOT NULL,
    CONSTRAINT UQ_FactPayment_OrderSequence UNIQUE (OrderKey, PaymentSequential)
);

COMMIT TRANSACTION;
