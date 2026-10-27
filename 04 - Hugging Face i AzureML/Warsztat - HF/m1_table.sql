CREATE TABLE sklep.Products (
    product_id    INT            PRIMARY KEY,
    product_name  NVARCHAR(100)  NOT NULL,
    category      NVARCHAR(50)   NOT NULL,
    price         DECIMAL(10,2)  NOT NULL
);
 
CREATE TABLE sklep.Reviews (
    review_id     INT IDENTITY(1,1) PRIMARY KEY,
    product_id    INT            NOT NULL REFERENCES sklep.Products(product_id),
    review_date   DATE           NOT NULL,
    rating        TINYINT        NOT NULL CHECK (rating BETWEEN 1 AND 5),
    review_text   NVARCHAR(2000) NOT NULL
);
GO
