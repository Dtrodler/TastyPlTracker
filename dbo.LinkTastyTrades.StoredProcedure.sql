USE [OPTIONS]
GO
/****** Object:  StoredProcedure [dbo].[LinkTastyTrades]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		DT
-- Create date: 
-- Description:	Determines trades that are defence/continuation of previous trade
-- =============================================
CREATE PROCEDURE [dbo].[LinkTastyTrades] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- link trades
	with cte   -- trades are linked when at least one of the legs of the parent trade is executed at the same time as openning of a new trade on the same usymbol
	AS
	(
		SELECT DISTINCT  ptrades.TradeNo,  ctrades.TradeNo AS cTradeNo
		FROM            TastyTransactions AS ctt INNER JOIN
                         TastyTrades AS ctrades ON ctt.tradeNo = ctrades.TradeNo INNER JOIN
                         TastyTransactions AS ptt INNER JOIN
                         TastyTrades AS ptrades ON ptt.tradeNo = ptrades.TradeNo ON ctrades.TradeNo > ptrades.TradeNo AND ctrades.StartDate between dateadd(minute,0,ptt.Date) and dateadd(minute,1,ptt.Date)
						 AND ctrades.uSymbol = ptrades.uSymbol
						 where ctt.type not in ('Money Movement','Receive Deliver') and ptt.type not in ('Money Movement','Receive Deliver')
				
	)
	UPDATE tt
	SET tt.ParentTradeNo =cte.TradeNo 
	from dbo.TastyTrades tt inner join cte on tt.TradeNo=cte.cTradeNo;
--	where tt.ParentTradeNo is null ;

	-- update parent TradeNo for assigned options so that assigned underlaying trade can be linked to original trade
	with assignedOptionTrades
	as
	(
		SELECT distinct
		tt.tradeNo as assignedOptionTradeNo
	   ,ts.tradeNo as underlyingTradeNo
		FROM [OPTIONS].[dbo].[TastyTransactions] tt  
		inner join TastyTransactions ts on tt.Date=ts.Date and tt.uSymbol =ts.uSymbol  and tt.Strike =abs(ts.AvePrice) 
		where (tt.Description like '%assignment%' or tt.Description like '%exercise%') and ts.InstrumentType = 'Equity'

		UNION

		SELECT distinct
		tt.tradeNo as assignedOptionTradeNo
	   ,ts.tradeNo as underlyingTradeNo
		FROM [OPTIONS].[dbo].[TastyTransactions] tt   -- tt original trade (option assignment/exercise)  , ts - new trade (assigned future) 
		inner join TastyTransactions ts on tt.Date=ts.Date and tt.uSymbol =ts.Symbol  -- no link between strike and price, as futures are reconciled daily,  also link uSymbol (original option trade) with symbol (assigned future) 
		where (tt.Description like '%assignment%' or tt.Description like '%exercise%') and ts.InstrumentType = 'Future'
	)
	UPDATE  t
	SET t.ParentTradeNo=a.assignedOptionTradeNo
	FROM TastyTrades t INNER JOIN assignedOptionTrades a ON t.tradeNo =a.underlyingTradeNo; 




	--calculate number of adjustments (=number of child trades)
	with
	cte
	as
	(
		select ParentTradeNo, tradeNo  from TastyTrades where ParentTradeNo is not null 
		union all
		select p.ParentTradeNo, c.tradeNo from TastyTrades as p inner join cte as c on p.tradeNo=c.ParentTradeNo   
	),
	TradeAjustments
	as
	(
		select ParentTradeNo, 
		count(*) as NoOfChildTrades 
		from cte where ParentTradeNo is not null
		group by ParentTradeNo 
    )
	update t
	set t.NoOfAdjustments =ta.NoOfChildTrades 
	from dbo.TastyTrades t inner join TradeAjustments ta on t.TradeNo =ta.ParentTradeNo ;

	--determine the topparentTradeNo
	with
	cte
	as
	(
		select ParentTradeNo, tradeNo  from TastyTrades where ParentTradeNo is not null
		union all
		select p.ParentTradeNo, c.tradeNo from TastyTrades as p inner join cte as c on p.tradeNo=c.ParentTradeNo   
	),
	TradeAjustments
	as
	(
		select TradeNo, min(ParentTradeNo) as TopParentTradeNo
		from cte where ParentTradeNo is not null
		group by TradeNo 
    )
	update t
	set t.TopParentTradeNo =ta.TopParentTradeNo  
	from dbo.TastyTrades t inner join TradeAjustments ta on t.TradeNo =ta.TradeNo ;




END
GO
