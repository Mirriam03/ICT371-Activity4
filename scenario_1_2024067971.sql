-- =====================================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 1: University Library Book Loans
-- Name: Miriam Kamwana        Student Number: 2024067971
-- =====================================================================

DROP TABLE IF EXISTS book_loans;
DROP TABLE IF EXISTS books;

-- 1. Tables and sample data ------------------------------------------
CREATE TABLE books (
    book_id          SERIAL PRIMARY KEY,
    title            VARCHAR(100) NOT NULL,
    available_copies INT NOT NULL CHECK (available_copies >= 0)
);

CREATE TABLE book_loans (
    loan_id        SERIAL PRIMARY KEY,
    book_id        INT NOT NULL REFERENCES books(book_id),
    student_number VARCHAR(15) NOT NULL,
    quantity       INT NOT NULL CHECK (quantity > 0),
    loan_status    VARCHAR(10) NOT NULL DEFAULT 'BORROWED'
                   CHECK (loan_status IN ('BORROWED','RETURNED'))
);

INSERT INTO books (title, available_copies) VALUES
    ('Database Systems',     5),
    ('Computer Networks',    2),
    ('Operating Systems',   10),
    ('Discrete Mathematics', 0);

-- 2. IF / ELSIF / ELSE -----------------------------------------------
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT title, available_copies FROM books ORDER BY book_id LOOP
        IF rec.available_copies = 0 THEN
            RAISE NOTICE '% -> UNAVAILABLE', rec.title;
        ELSIF rec.available_copies <= 3 THEN
            RAISE NOTICE '% -> LOW on copies (%)', rec.title, rec.available_copies;
        ELSE
            RAISE NOTICE '% -> Sufficiently stocked (%)', rec.title, rec.available_copies;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR -------------------------------------------
DO $$
DECLARE
    n INT := 1;
BEGIN
    WHILE n <= 3 LOOP
        RAISE NOTICE 'Overdue reminder number: %', n;
        n := n + 1;
    END LOOP;

    FOR shelf IN 1..3 LOOP
        RAISE NOTICE 'Library shelf number: %', shelf;
    END LOOP;
END $$;

-- 4. borrow_book procedure -------------------------------------------
CREATE OR REPLACE PROCEDURE borrow_book(p_book_id INT, p_student VARCHAR, p_qty INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available INT;
BEGIN
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Invalid quantity: % (must be greater than zero)', p_qty;
    END IF;

    SELECT available_copies INTO v_available
    FROM books WHERE book_id = p_book_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Book % does not exist. No loan recorded.', p_book_id;
        RETURN;
    END IF;

    IF v_available < p_qty THEN
        RAISE NOTICE 'Request for % copies REJECTED for book % (only % available).',
                     p_qty, p_book_id, v_available;
        RETURN;
    END IF;

    UPDATE books SET available_copies = available_copies - p_qty WHERE book_id = p_book_id;
    INSERT INTO book_loans (book_id, student_number, quantity)
    VALUES (p_book_id, p_student, p_qty);
    RAISE NOTICE 'Loan recorded: student % borrowed % copy/copies of book %.',
                 p_student, p_qty, p_book_id;
END $$;

-- 5. Two valid loans and one request exceeding stock -------------------
CALL borrow_book(1, '2024001001', 2);   -- valid
CALL borrow_book(3, '2024001002', 3);   -- valid
CALL borrow_book(2, '2024001003', 5);   -- exceeds available copies (only 2)

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- 6. return_book procedure --------------------------------------------
CREATE OR REPLACE PROCEDURE return_book(p_loan_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status  VARCHAR;
    v_book_id INT;
    v_qty     INT;
BEGIN
    SELECT loan_status, book_id, quantity INTO v_status, v_book_id, v_qty
    FROM book_loans WHERE loan_id = p_loan_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Loan % not found.', p_loan_id;
    ELSIF v_status = 'RETURNED' THEN
        RAISE NOTICE 'Loan % was already returned. Copies NOT restored again.', p_loan_id;
    ELSE
        UPDATE book_loans SET loan_status = 'RETURNED' WHERE loan_id = p_loan_id;
        UPDATE books SET available_copies = available_copies + v_qty WHERE book_id = v_book_id;
        RAISE NOTICE 'Loan % returned. % copy/copies restored.', p_loan_id, v_qty;
    END IF;
END $$;

CALL return_book(1);   -- first call: restores copies
CALL return_book(1);   -- second call: must not restore again

SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;

-- 7. Explicit cursor: books with few copies remaining (3 or fewer) -----
DO $$
DECLARE
    cur_low CURSOR FOR
        SELECT book_id, title, available_copies
        FROM books WHERE available_copies <= 3 ORDER BY available_copies;
    r RECORD;
BEGIN
    OPEN cur_low;
    LOOP
        FETCH cur_low INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Few copies left: [%] % - % copies', r.book_id, r.title, r.available_copies;
    END LOOP;
    CLOSE cur_low;
END $$;

-- 8. Zero copies -> invalid quantity handled with EXCEPTION ------------
DO $$
BEGIN
    CALL borrow_book(1, '2024001004', 0);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- 9. Final state -------------------------------------------------------
SELECT * FROM books ORDER BY book_id;
SELECT * FROM book_loans ORDER BY loan_id;
