-- =====================================================================
-- ICT371 PostgreSQL Scenario Assignment
-- Scenario 3: Student Hostel Room Allocation
-- Name: Miriam Kamwana        Student Number: 2024067971
-- =====================================================================

DROP TABLE IF EXISTS allocations;
DROP TABLE IF EXISTS hostel_rooms;

-- 1. Tables and sample data ------------------------------------------
CREATE TABLE hostel_rooms (
    room_id          SERIAL PRIMARY KEY,
    room_name        VARCHAR(20) NOT NULL,
    available_spaces INT NOT NULL CHECK (available_spaces >= 0)
);

CREATE TABLE allocations (
    allocation_id  SERIAL PRIMARY KEY,
    student_number VARCHAR(15) NOT NULL,
    room_id        INT NOT NULL REFERENCES hostel_rooms(room_id),
    status         VARCHAR(10) NOT NULL DEFAULT 'ACTIVE'
                   CHECK (status IN ('ACTIVE','COMPLETED'))
);

INSERT INTO hostel_rooms (room_name, available_spaces) VALUES
    ('Block A - Room 101', 4),
    ('Block A - Room 102', 1),
    ('Block B - Room 201', 0);

-- 2. IF / ELSIF / ELSE -----------------------------------------------
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT room_name, available_spaces FROM hostel_rooms ORDER BY room_id LOOP
        IF rec.available_spaces = 0 THEN
            RAISE NOTICE '% -> FULL', rec.room_name;
        ELSIF rec.available_spaces = 1 THEN
            RAISE NOTICE '% -> ONE space left', rec.room_name;
        ELSE
            RAISE NOTICE '% -> Several spaces (%)', rec.room_name, rec.available_spaces;
        END IF;
    END LOOP;
END $$;

-- 3. WHILE and numeric FOR -------------------------------------------
DO $$
DECLARE
    d INT := 1;
BEGIN
    WHILE d <= 3 LOOP
        RAISE NOTICE 'Hostel inspection day %', d;
        d := d + 1;
    END LOOP;

    FOR i IN 1..3 LOOP
        RAISE NOTICE 'Room check number %', i;
    END LOOP;
END $$;

-- 4. allocate_room procedure -------------------------------------------
CREATE OR REPLACE PROCEDURE allocate_room(p_student VARCHAR, p_room_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_spaces INT;
BEGIN
    IF p_student IS NULL OR TRIM(p_student) = '' THEN
        RAISE EXCEPTION 'Invalid input: student number cannot be blank';
    END IF;

    SELECT available_spaces INTO v_spaces
    FROM hostel_rooms WHERE room_id = p_room_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Room % does not exist. No allocation recorded.', p_room_id;
        RETURN;
    END IF;

    IF v_spaces < 1 THEN
        RAISE NOTICE 'Allocation REJECTED: room % is full.', p_room_id;
        RETURN;
    END IF;

    UPDATE hostel_rooms SET available_spaces = available_spaces - 1 WHERE room_id = p_room_id;
    INSERT INTO allocations (student_number, room_id) VALUES (TRIM(p_student), p_room_id);
    RAISE NOTICE 'Student % allocated to room %.', TRIM(p_student), p_room_id;
END $$;

-- 5. Two valid allocations and one to a full room ----------------------
CALL allocate_room('2024001001', 1);   -- valid
CALL allocate_room('2024001002', 2);   -- valid (room becomes full)
CALL allocate_room('2024001003', 3);   -- room already full

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- 6. check_out procedure ------------------------------------------------
CREATE OR REPLACE PROCEDURE check_out(p_allocation_id INT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status  VARCHAR;
    v_room_id INT;
BEGIN
    SELECT status, room_id INTO v_status, v_room_id
    FROM allocations WHERE allocation_id = p_allocation_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE NOTICE 'Allocation % not found.', p_allocation_id;
    ELSIF v_status = 'COMPLETED' THEN
        RAISE NOTICE 'Allocation % already checked out. No extra space freed.', p_allocation_id;
    ELSE
        UPDATE allocations SET status = 'COMPLETED' WHERE allocation_id = p_allocation_id;
        UPDATE hostel_rooms SET available_spaces = available_spaces + 1 WHERE room_id = v_room_id;
        RAISE NOTICE 'Allocation % checked out. One bed space released.', p_allocation_id;
    END IF;
END $$;

CALL check_out(1);   -- first call frees a space
CALL check_out(1);   -- second call must not free another

SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;

-- 7. Explicit cursor: full or nearly full rooms (1 or fewer spaces) ------
DO $$
DECLARE
    cur_rooms CURSOR FOR
        SELECT room_id, room_name, available_spaces
        FROM hostel_rooms WHERE available_spaces <= 1 ORDER BY room_id;
    r RECORD;
BEGIN
    OPEN cur_rooms;
    LOOP
        FETCH cur_rooms INTO r;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE 'Full / nearly full: [%] % - % space(s) left', r.room_id, r.room_name, r.available_spaces;
    END LOOP;
    CLOSE cur_rooms;
END $$;

-- 8. Blank student number handled with EXCEPTION -------------------------
DO $$
BEGIN
    CALL allocate_room('   ', 1);
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error handled: %', SQLERRM;
END $$;

-- 9. Final state -----------------------------------------------------------
SELECT * FROM hostel_rooms ORDER BY room_id;
SELECT * FROM allocations ORDER BY allocation_id;
