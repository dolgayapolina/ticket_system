--предстваления для организаторов 

--Информация о заполняемости зон
--DROP VIEW IF EXISTS public.v_заполняемость_зон;
CREATE VIEW public.v_заполняемость_зон AS(
SELECT
	место_события.id_события AS "ID события",
	зона.id_зоны             AS "ID зоны",
    public.зона.название          AS "Зона",
    COUNT(public.место.id_места)   AS "Всего мест",
    COUNT(public.занятое_место.id_места_события) AS "Занято мест",
    ROUND((COUNT(public.занятое_место.id_места_события)::NUMERIC / NULLIF(COUNT(public.место.id_места), 0)) * 100, 2) AS "Процент заполняемости"
FROM public.место_события 
JOIN public.место ON public.место_события.id_места = public.место.id_места
JOIN public.зона  ON public.место.id_зоны = public.зона.id_зоны
LEFT JOIN public.занятое_место ON public.место_события.id_места_события = public.занятое_место.id_места_события
GROUP BY public.место_события.id_события, public.зона.id_зоны, public.зона.название
);

--Финансовая отчетность, сумма продаж, сумма возвратов 
--DROP VIEW IF EXISTS public.v_финансовая_отчетность;
CREATE VIEW public.v_финансовая_отчетность AS (
SELECT 
	событие.id_события          AS "ID события",
    событие.название           AS "Событие",
    COUNT(DISTINCT билет.id_билета) AS "Всего билетов",
    SUM(билет.цена_билета)   AS "Общая сумма продаж",
    COALESCE(SUM(возврат.сумма_возврата), 0) AS "Сумма возвратов",
    SUM(билет.цена_билета) - COALESCE(SUM(возврат.сумма_возврата), 0) AS "Чистая выручка"
FROM public.событие
JOIN public.место_события ON public.событие.id_события = public.место_события.id_события
JOIN public.билет ON public.место_события.id_места_события = public.билет.id_места_события
LEFT JOIN public.платеж ON public.билет.id_билета = public.платеж.id_билета
LEFT JOIN public.возврат ON public.платеж.id_платежа = public.возврат.id_платежа
WHERE билет.id_статуса_билета IN (2, 3)
GROUP BY событие.id_события, событие.название
);


--Активные брони 
--DROP VIEW IF EXISTS public.v_активные_брони;
CREATE VIEW public.v_активные_брони AS (
SELECT 
	событие.id_события          AS "ID события", 
    событие.название            AS "Событие",
   	билет.id_билета,
    билет.дата_создания AS "Дата создания",
    событие.срок_брони_мин AS "Срок брони",
    билет.дата_создания + (событие.срок_брони_мин || ' minutes')::INTERVAL AS "Время истечения",
    ROUND(EXTRACT(EPOCH FROM (
        (билет.дата_создания + (событие.срок_брони_мин || ' minutes')::INTERVAL) - now()
    )) / 60, 1) AS "Осталось минут"
FROM public.билет
JOIN public.место_события ON public.билет.id_места_события = public.место_события.id_места_события
JOIN public.событие ON public.место_события.id_события = public.событие.id_события
WHERE билет.id_статуса_билета = 1
  AND now() < билет.дата_создания + (событие.срок_брони_мин || ' minutes')::INTERVAL
);


