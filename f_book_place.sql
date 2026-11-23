--функция бронирования места (защита от двойной продажи) 
--DROP FUNCTION IF EXISTS public.забронировать_место(BIGINT, BIGINT);

DROP FUNCTION IF EXISTS public.забронировать_место(BIGINT, BIGINT);

CREATE OR REPLACE FUNCTION public.забронировать_место(
    inp_id_места_события BIGINT, 
    inp_id_покупателя BIGINT
) RETURNS BIGINT AS $$
DECLARE
    v_id_билета BIGINT;
    v_цена NUMERIC;
    v_id_версии INTEGER;
    v_id_события INTEGER;
    v_id_зоны INTEGER;
BEGIN
    -- 1. Узнаем, к какому событию и зоне относится место
    SELECT мс.id_события, м.id_зоны INTO v_id_события, v_id_зоны
    FROM public.место_события мс
    JOIN public.место м ON мс.id_места = м.id_места
    WHERE мс.id_места_события = inp_id_места_события;

    -- 2. Считаем цену
    v_цена := public.рассчитать_цену(v_id_события, v_id_зоны);
    
    -- 3. Запоминаем актуальную версию правил
    SELECT id_версии INTO v_id_версии 
    FROM public.версия_правил_цен 
    WHERE id_события = v_id_события AND действует_с <= now() 
    ORDER BY действует_с DESC LIMIT 1;

    -- 4. Занимаем место (защита от двойной продажи)
    INSERT INTO public.занятое_место (id_места_события) 
    VALUES (inp_id_места_события);

    -- 5. Создаем билет (статус 1 - забронирован)
    INSERT INTO public.билет (
        id_места_события, id_покупателя, id_версии, id_статуса_билета, цена_билета
    )
    VALUES (
        inp_id_места_события, inp_id_покупателя, v_id_версии, 1, v_цена
    )
    RETURNING id_билета INTO v_id_билета;

    RETURN v_id_билета;

EXCEPTION 
    WHEN unique_violation THEN
        RAISE EXCEPTION 'Место (id: %) уже занято', inp_id_места_события;
END;
$$ LANGUAGE plpgsql;