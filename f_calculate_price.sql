--функция динамического формирования цены 
--DROP FUNCTION IF EXISTS public.рассчитать_цену(INTEGER, INTEGER);


CREATE OR REPLACE FUNCTION public.рассчитать_цену (
	inp_id_события INTEGER,
	inp_id_зоны INTEGER
) RETURNS NUMERIC AS $$
DECLARE
	v_id_версии INTEGER;
    v_базовая_цена NUMERIC;
    v_учитывать_спрос BOOLEAN;
    v_kt NUMERIC := 1.0;
    v_ks NUMERIC := 1.0;
    v_дней_до_события NUMERIC;
    v_заполняемость NUMERIC;
BEGIN 
	--получаем текущую версию 
	SELECT id_версии INTO v_id_версии 
    FROM public.версия_правил_цен 
    WHERE id_события = inp_id_события AND действует_с <= now() 
    ORDER BY действует_с DESC LIMIT 1; --обеспечивает самую последнюю версию цены

	--получаем базовую цену и необходимость учитывать спрос
	SELECT базовая_цена, учитывать_спрос INTO v_базовая_цена, v_учитывать_спрос
    FROM public.базовая_цена_зоны 
    WHERE id_версии = v_id_версии AND id_зоны = inp_id_зоны;
	
	--считаем количество дней до события 
	SELECT EXTRACT(EPOCH FROM (дата_начала - now())) / 86400.0
    INTO v_дней_до_события
    FROM public.событие WHERE id_события = inp_id_события;

	--получаем коэффициент по времени, тоже самый актуальный благодаря сортировки по убыванию
	SELECT коэффициент INTO v_kt 
    FROM public.коэффициент_времени 
    WHERE id_версии = v_id_версии AND мин_дней_до_события <= v_дней_до_события
    ORDER BY мин_дней_до_события DESC LIMIT 1;

	IF v_учитывать_спрос THEN
		SELECT "Процент заполняемости" INTO v_заполняемость
        FROM public.v_заполняемость_зон
        WHERE "ID события" = inp_id_события AND "ID зоны" = inp_id_зоны;
		SELECT коэффициент INTO v_ks 
        FROM public.коэффициент_спроса 
        WHERE id_версии = v_id_версии AND порог_заполнения_проц < COALESCE(v_заполняемость, 0)
        ORDER BY порог_заполнения_проц DESC LIMIT 1;
	END IF;
	
	RETURN ROUND(
        COALESCE(v_базовая_цена, 0) * 
        COALESCE(v_kt, 1.0) * 
        COALESCE(v_ks, 1.0), 
    2);
END;
$$ LANGUAGE plpgsql;