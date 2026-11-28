-- Run once for the verified local SSAS2022 service identity.
-- On another machine, replace both the account and database explicitly.
USE master;
IF SUSER_ID(N'NT Service\MSOLAP$SSAS2022') IS NULL
    CREATE LOGIN [NT Service\MSOLAP$SSAS2022] FROM WINDOWS;
USE OlistDW_Test;
IF USER_ID(N'NT Service\MSOLAP$SSAS2022') IS NULL
    CREATE USER [NT Service\MSOLAP$SSAS2022] FOR LOGIN [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimDate TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimCustomer TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimProduct TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimSeller TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimPayment TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.DimOrder TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.FactSales TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.FactOrder TO [NT Service\MSOLAP$SSAS2022];
GRANT SELECT ON dbo.FactPayment TO [NT Service\MSOLAP$SSAS2022];
