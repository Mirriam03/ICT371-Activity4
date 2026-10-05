-- =====================================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 4: Campus Clinic Medicine Dispensing
-- Name: Miriam Kamwana        Student Number: 2024067971
-- =====================================================================

DROP TABLE IF EXISTS dispensing_records;
DROP TABLE IF EXISTS medicines;

-- 1. Tables and sample data ------------------------------------------
CREATE TABLE medicines (
    medicine_id    SERIAL PRIMARY KEY,
    medicine_name  VARCHAR(100) NOT NULL,
    stock_quantity INT NOT NULL CHECK (stock_quantity >= 0)
);

CREATE TABLE dispensing_records (
    record_id      SERIAL PRIMARY KEY,
    medicine_id    INT NOT NULL REFERENCES medicines(medicine_id),
    student_number VARCHAR(15) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    status         VARCHAR(10) NOT NULL DEFAULT 'DISPENSED'
                   CHECK (status IN ('DISPENSED','REVERSED'))
);

INSERT INTO medicines (medicine_name, stock_quantity) VALUES
    ('Paracetamol 500mg',  100),
    ('Amoxicillin 250mg',    8),
    ('Coartem (Artemether-Lumefantrine)', 0);

-- 2. IF / ELSIF / ELSE -----------------------------------------------
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT medicine_name, stock_quantity FROM medicines ORDER BY medicine_id LOOP
        IF rec.stock_quantity = 0 THEN
            RAISE NOTICE '% -> OUT OF STOCK', rec.medicine_name;
        ELSIF rec.stock_quantity <= 10 THEN
            RAISE NOTICE '% -> LOW stock (%)', rec.medicine_name, rec.stock_quantity;
        ELSE
            RAISE NOTICE '% -> Sufficiently stocked (%)', rec.medicine_name, rec.stock_quantity;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR -------------------------------------------
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Stock review day %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Shelf inspection number %', i;
    END LOOP;
END $$;

-- 4. dispense_medicine procedure ---------------------------------------
CREATE OR REPLACE PROCEDURE dispense_medicine(p_medicine_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid dispensing quantity: % (must be greater than zero)', p_qty;
    END IF;

    SELECT stock_quantity INTO v_stock
    FROM medicines WHERE medicine_id = p_medicine_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Medicine % does not exist. Nothing dispensed.', p_medicine_id;
        RETURN;
    END IF;

    IF v_stock < p_qty THEN
        RAISE NOTICE 'Dispensing of % units REJECTED for medicine % (only % in stock).',
                     p_qty, p_medicine_id, v_stock;
        RETURN;
    END IF;

    UPDATE medicines SET stock_quantity = stock_quantity - p_qty WHERE medicine_id = p_medicine_id;
    INSERT INTO dispensing_records (medicine_id, student_number, quantity)
    VALUES (p_medicine_id, p_student, p_qty);
    RAISE NOTICE 'Dispensed % unit(s) of medicine % to student %.', p_qty, p_medicine_id, p_student;
END $$;

-- 5. Two valid quantities and one exceeding stock ------------------------
CALL dispense_medicine(1, '2024001001', 20);   -- valid
CALL dispense_medicine(2, '2024001002',  3);   -- valid
CALL dispense_medicine(2, '2024001003', 50);   -- exceeds stock

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- 6. reverse_dispensing procedure ----------------------------------------
CREATE OR REPLACE PROCEDURE reverse_dispensing(p_record_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status      VARCHAR;
    v_medicine_id INT;
    v_qty         INT;
BEGIN
    SELECT status, medicine_id, quantity INTO v_status, v_medicine_id, v_qty
    FROM dispensing_records WHERE record_id = p_record_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Dispensing record % not found.', p_record_id;
    ELSIF v_status = 'REVERSED' THEN
        RAISE NOTICE 'Record % already reversed. Stock NOT restored again.', p_record_id;
    ELSE
        UPDATE dispensing_records SET status = 'REVERSED' WHERE record_id = p_record_id;
        UPDATE medicines SET stock_quantity = stock_quantity + v_qty WHERE medicine_id = v_medicine_id;
        RAISE NOTICE 'Record % reversed. % unit(s) restored to stock.', p_record_id, v_qty;
    END IF;
END $$;

CALL reverse_dispensing(1);   -- first call restores stock
CALL reverse_dispensing(1);   -- second call must not restore again

SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;

-- 7. Explicit cursor: medicines below a low-stock threshold ---------------
DO $$
DECLARE
    v_threshold INT := 20;
    cur_low CURSOR (p_limit INT) FOR
        SELECT medicine_id, medicine_name, stock_quantity
        FROM medicines WHERE stock_quantity < p_limit ORDER BY stock_quantity;
    r RECORD;
BEGIN
    OPEN cur_low(v_threshold);
    LOOP
        FETCH cur_low INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Below % units: [%] % - % in stock', v_threshold, r.medicine_id, r.medicine_name, r.stock_quantity;
    END LOOP;
    CLOSE cur_low;
END $$;

-- 8. Negative quantity handled with EXCEPTION ----------------------------
DO $$
BEGIN
    CALL dispense_medicine(1, '2024001004', -5);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- 9. Final state --------------------------------------------------------------
SELECT * FROM medicines ORDER BY medicine_id;
SELECT * FROM dispensing_records ORDER BY record_id;
