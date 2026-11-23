--функция изменения статуса на Оплачено после Брони 
--DROP FUNCTION IF EXISTS public.оплатить_билет(BIGINT);

CREATE OR REPLACE FUNCTION public.оплатить_билет(
    inp_id_билета BIGINT
) RETURNS VARCHAR AS $$ 
DECLARE
    v_дата_создания TIMESTAMPTZ;
    v_ttl SMALLINT;
BEGIN
    -- получаем информацию о брони 
    SELECT билет.дата_создания, событие.срок_брони_мин INTO v_дата_создания, v_ttl
    FROM public.билет 
    JOIN public.место_события ON public.билет.id_места_события = public.место_события.id_места_события
    JOIN public.событие ON public.место_события.id_события = public.событие.id_события
    WHERE public.билет.id_билета = inp_id_билета;

    -- проверка срока жизни брони 
    IF now() > v_дата_создания + (v_ttl || ' minutes')::INTERVAL THEN	
        -- Меняем статус на 4
        UPDATE public.билет 
        SET id_статуса_билета = 4 
        WHERE id_билета = inp_id_билета;
        
        -- Освобождаем место
        DELETE FROM public.занятое_место 
        WHERE id_места_события = (SELECT id_места_события FROM public.билет WHERE id_билета = inp_id_билета);
        
        -- Возвращаем текст для приложения
        RETURN 'ОШИБКА: Время брони истекло. Место освобождено, оплата отменена.';
    END IF;
	
    -- Если время не истекло, проводим оплату
    UPDATE public.билет 
    SET id_статуса_билета = 2 
    WHERE id_билета = inp_id_билета;
    
    INSERT INTO public.платеж (id_билета, дата_платежа) 
    VALUES (inp_id_билета, now());
    
    RETURN 'УСПЕХ: Билет успешно оплачен.';
END;
$$ LANGUAGE plpgsql;