--процедура удаления записей о событии которое прошло 
--DROP PROCEDURE IF EXISTS public.удалить_прошедшее_событие(INTEGER);

CREATE OR REPLACE PROCEDURE public.удалить_прошедшее_событие(
    inp_id_события INTEGER
) 
AS $$
DECLARE
    v_дата_начала TIMESTAMPTZ;
BEGIN
    --проверяем, что событие вообще существует и уже прошло
    SELECT дата_начала INTO v_дата_начала 
    FROM public.событие 
    WHERE id_события = inp_id_события;

    IF v_дата_начала IS NULL THEN
        RAISE EXCEPTION 'Событие с id % не найдено', inp_id_события;
    END IF;

    IF v_дата_начала > now() THEN
        RAISE EXCEPTION 'Нельзя удалить событие, которое еще не прошло (дата: %)', v_дата_начала;
    END IF;

    --удаляем финансовые документы (возвраты и платежи)
    DELETE FROM public.возврат 
    WHERE id_платежа IN (
        SELECT id_платежа FROM public.платеж 
        WHERE id_билета IN (
            SELECT id_билета FROM public.билет 
            WHERE id_места_события IN (
                SELECT id_места_события FROM public.место_события WHERE id_события = inp_id_события
            )
        )
    );

    DELETE FROM public.платеж 
    WHERE id_билета IN (
        SELECT id_билета FROM public.билет 
        WHERE id_места_события IN (
            SELECT id_места_события FROM public.место_события WHERE id_события = inp_id_события
        )
    );

    --удаляем занятость мест
    DELETE FROM public.занятое_место 
    WHERE id_места_события IN (
        SELECT id_места_события FROM public.место_события WHERE id_события = inp_id_события
    );

    --удаляем билеты
    DELETE FROM public.билет 
    WHERE id_места_события IN (
        SELECT id_места_события FROM public.место_события WHERE id_события = inp_id_события
    );

    DELETE FROM public.место_события WHERE id_события = inp_id_события;

    DELETE FROM public.базовая_цена_зоны 
    WHERE id_версии IN (SELECT id_версии FROM public.версия_правил_цен WHERE id_события = inp_id_события);

    DELETE FROM public.коэффициент_времени 
    WHERE id_версии IN (SELECT id_версии FROM public.версия_правил_цен WHERE id_события = inp_id_события);

    DELETE FROM public.коэффициент_спроса 
    WHERE id_версии IN (SELECT id_версии FROM public.версия_правил_цен WHERE id_события = inp_id_события);

    DELETE FROM public.версия_правил_цен WHERE id_события = inp_id_события;
    
    DELETE FROM public.правило_возврата WHERE id_события = inp_id_события;

    DELETE FROM public.событие WHERE id_события = inp_id_события;

END;
$$ LANGUAGE plpgsql;