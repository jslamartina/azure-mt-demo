CREATE TABLE TenantTable1
(
    ID       INT IDENTITY  NOT NULL,
    SomeData NVARCHAR(256) NOT NULL
);

INSERT INTO TenantTable1(SomeData)
VALUES ('SomeTenantLevelData1'),
       ('SomeTenantLevelData2'),
       ('SomeTenantLevelData3'),
       ('SomeTenantLevelData4'),
       ('SomeTenantLevelData5');

CREATE TABLE TenantTable2
(
    ID       INT IDENTITY  NOT NULL,
    SomeOtherData NVARCHAR(256) NOT NULL,
    TenantTable1_FK INT NOT NULL
);

INSERT INTO TenantTable2(SomeOtherData,
                         TenantTable1_FK)
VALUES ('SomeOtherTenantLevelData1', 1),
       ('SomeOtherTenantLevelData2', 2),
       ('SomeOtherTenantLevelData3', 3),
       ('SomeOtherTenantLevelData4', 4),
       ('SomeOtherTenantLevelData5', 5);