CREATE TABLE TenantDatabase
(
    TenantID       INT IDENTITY  NOT NULL,
    DatabaseServer NVARCHAR(256) NOT NULL,
    DatabaseName   NVARCHAR(256) NOT NULL
);

INSERT INTO TenantDatabase(DatabaseServer,
                           DatabaseName)
VALUES ('sql-server-mt-demo.database.windows.net', 'Tenant_A'),
       ('sql-server-mt-demo.database.windows.net', 'Tenant_B'),
       ('sql-server-mt-demo.database.windows.net', 'Tenant_C'),
       ('sql-server-mt-demo.database.windows.net', 'Tenant_D'),
       ('sql-server-mt-demo.database.windows.net', 'Tenant_E');