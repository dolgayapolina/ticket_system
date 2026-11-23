--функция возврата брони 
--DROP FUNCTION IF EXISTS public.вернуть_билет(BIGINT);

CREATE OR REPLACE FUNCTION public.вернуть_билет(
    inp_id_билета BIGINT
) RETURNS NUMERIC AS $$
DECLARE
    v_цена NUMERIC;
    v_процент NUMERIC;
    v_дней_до NUMERIC;
    v_id_события INTEGER;
    v_сумма_возврата NUMERIC;
    v_id_платежа BIGINT;
    v_id_места_события BIGINT;
    v_статус_билета SMALLINT;
BEGIN
    --получаем информацию о билете
    SELECT билет.цена_билета, место_события.id_события, место_события.id_места_события, билет.id_статуса_билета,
           EXTRACT(EPOCH FROM (событие.дата_начала - now())) / 86400.0
    INTO v_цена, v_id_события, v_id_места_события, v_статус_билета, v_дней_до
    FROM public.билет
    JOIN public.место_события ON public.билет.id_места_события = public.место_события.id_места_события
    JOIN public.событие ON public.место_события.id_события = public.событие.id_события
    WHERE public.билет.id_билета = inp_id_билета;

    --проверка того, что билет уже оплачен
    IF v_статус_билета != 2 THEN
        RAISE EXCEPTION 'Можно вернуть только оплаченный билет (текущий статус: %)', v_статус_билета;
    END IF;

    --получаем процент возврата
    SELECT процент_возврата INTO v_процент
    FROM public.правило_возврата
    WHERE id_события = v_id_события AND мин_дней_до_события <= v_дней_до
    ORDER BY мин_дней_до_события DESC LIMIT 1;

    --считаем сумму возврата
    v_сумма_возврата := v_цена * (COALESCE(v_процент, 0) / 100);

    --изменение статуса на 5 - "возвращен"
    UPDATE public.билет 
    SET id_статуса_билета = 5
    WHERE id_билета = inp_id_билета;

    --освобождение места
    DELETE FROM public.занятое_место 
    WHERE id_места_события = v_id_места_события;

    --записываем платеж
    SELECT id_платежа INTO v_id_платежа FROM платеж WHERE id_билета = inp_id_билета;
    
    IF v_id_платежа IS NOT NULL THEN
        INSERT INTO public.возврат (id_платежа, сумма_возврата) 
        VALUES (v_id_платежа, v_сумма_возврата);
    END IF;

    -- Возвращаем сумму, которую вернули пользователю
    RETURN v_сумма_возврата;
END;
$$ LANGUAGE plpgsql;