USE [OPTIONS]
GO
/****** Object:  StoredProcedure [dbo].[LoadTastyTransactions]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO















-- =============================================
-- Author:		DT
-- Create date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [dbo].[LoadTastyTransactions] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	declare @LastUploadedDate as smalldatetime
	SELECT @LastUploadedDate =coalesce(max(date),cast('20180101' as smalldatetime)) from dbo.TastyTransactions;


	-- first insert all transactions (apart from closing transactions that have more then 1 lot size (qty>1))
	INSERT INTO dbo.TastyTransactions 
	(
	   [Date]
      ,[Type]
      ,[Action]
      ,[Symbol]
      ,[InstrumentType]
      ,[Description]
      ,[Value]
      ,[Qty]
      ,[AvePrice]
      ,[Commissions]
      ,[Fees]
      ,[Multiplier]
      ,[UnderlyingSymbol]
      ,[ExpDate]
      ,[Strike]
      ,[OptType]
	  ,[OrigQty]
	)

	SELECT


		cast(left(date,19) as smalldatetime) as Date  --round seconds to whole minutes
      ,[Type]
      ,[Action]
      ,[Symbol]
      ,[InstrumentType]
      ,[Description]
      ,[Value]
      ,[Qty]
      ,[AvePrice]
      ,[Commissions]
      ,[Fees]
      ,[Multiplier]
      ,[UnderlyingSymbol]
      ,[ExpDate]
      ,[Strike]
      ,[OptType]
	  ,[Qty]
	  FROM dbo.StagingTastyTransactions 
	  where 
	  (((action not like '%CLOSE%' and Description not like 'Removal%' and InstrumentType<>'Future' ) or ( InstrumentType='Future' and Type='Trade' and AvePrice=0 )) or qty<=1 or type='Money movement') and 
	  cast(left(date,19)  as smalldatetime )>@LastUploadedDate ;

	  -- then upload the closing transactions with more then 1 lot size
	  -- decompose these transactions into 1 lot trades
	  -- this is necessary to always find matching closing transactions. Imagine buying 10 shares of AAPL and then later additional 6, then closing 8 and later closing 8
	  -- without decomposing the closing trades into one lots, the matching opening trade could never be found  
	INSERT INTO dbo.TastyTransactions 
	(
	   [Date]
      ,[Type]
      ,[Action]
      ,[Symbol]
      ,[InstrumentType]
      ,[Description]
      ,[Value]
      ,[Qty]
      ,[AvePrice]
      ,[Commissions]
      ,[Fees]
      ,[Multiplier]
      ,[UnderlyingSymbol]
      ,[ExpDate]
      ,[Strike]
      ,[OptType]
	  ,[OrigQty]
	)

	SELECT

	  cast(left(date,19) as smalldatetime) as Date  --round seconds to whole minutes,
      ,[Type]
      ,[Action]
      ,[Symbol]
      ,[InstrumentType]
      ,[Description]
       ,[Value]/Qty as Value
      ,1 as Qty
      ,[AvePrice]
      ,[Commissions] / Qty as Commissions
      ,[Fees] /Qty as Fees
	  ,[Multiplier]
      ,[UnderlyingSymbol]
      ,[ExpDate]
      ,[Strike]
      ,[OptType]
	  ,[Qty]
	  FROM dbo.StagingTastyTransactions  inner join numbers on qty>= number
	  where 
	  ((action like '%CLOSE%' or Description like 'Removal%') or (InstrumentType='Future' and Type in('Trade') and AvePrice<>0)) and qty>1 and 
	  cast(left(date,19) as smalldatetime)>@LastUploadedDate ;

	  --temporary
	  update dbo.TastyTransactions
	  set symbol= replace(symbol,'RUTW', 'RUT') WHERE [UnderlyingSymbol]='RUT';




     --adjust futures  trade dates so that trades on the same usymbol (without the expiration part) within 5 minutes  are considered one trade 
	 -- this needed for interdelivery spreads which cannot be currently executed as one transaction in tastytrade
	with cte
	as
	(
		select TransactionId, Date, OrigDate, usymbol, dense_rank() over( partition by usymbol order by Date asc) as rno
		from tastytransactions where action in ('SELL','BUY') and InstrumentType ='Future'
	)
	update  cte2
	set cte2.OrigDate=cte2.Date,
	cte2.Date=cte.Date
	from cte inner join cte cte2 on left(cte.usymbol, len(cte.usymbol)-2)=left(cte2.usymbol, len(cte2.usymbol)-2) and cte.rno= cte2.rno-1
	where datediff(minute, cte.date, cte2.date) between 1 and 5;




---temp just for debugging
--delete from TastyTransactions where uSymbol <>'LVS';




	  --update tradeNo for trade opennings. Update only new opennings
	with OpenningTrades
	as
	(
	-- equity, options on equity, options on futures, futures
		SELECT t.Date,  t.uSymbol,  
		case when t.Type='Receive Deliver' then t.AvePrice else 1 end as AvePrice,   -- the AvePrice column is needed for special casses of assignment of shares from different strike options but same time of assignment
		(Select coalesce(max(tt.tradeNo),0) from TastyTransactions tt) + row_number() over (order by Date asc) as tradeNo,
		(Select coalesce(max(tt.uTradeSeqNo),0) from TastyTransactions tt where tt.uSymbol =t.uSymbol) +row_number() over (partition by  uSymbol order by Date asc) as uTradeSeqNo  -- trade sequence number for given underlaying used later to get the time difference between subsequent trades
		FROM TastyTransactions t where t.tradeNo is null and  ((t.action like '%OPEN') or (t.InstrumentType='Future' and t.Type='Trade' and t.AvePrice=0))  -- open future positions are recognized by average price equals to zero
		group by t.Date, t.usymbol, case when t.Type='Receive Deliver' then t.AvePrice else 1 end   -- the last grouping is for special casses of assignment of shares from different strike options but same time of assignment
	)

	update t
	set t.TradeNo= OpenningTrades.tradeNo , 
	t.uTradeSeqNo = OpenningTrades.uTradeSeqNo
	from dbo.tastytransactions t inner join OpenningTrades on t.usymbol =OpenningTrades.uSymbol and t.Date =OpenningTrades.Date and case when t.Type='Receive Deliver' then t.AvePrice else 1 end= OpenningTrades.AvePrice 
	where t.TradeNo is null and ( (t.action like '%OPEN') or (t.InstrumentType='Future' and t.Type='Trade' and t.AvePrice=0) ) ;


	--populate the TastyTrades table with new orders
	INSERT INTO TastyTrades (TradeNo,uSymbol, InstrumentType,StartDTE,legs,Symbols,StartDate,StartValue,uTradeSeqNo)
	SELECT tra.tradeNo, tra.uSymbol, left(tra.InstrumentType,6), 
		min(datediff(day,tra.Date,tra.ExpDate)) as startDTE,
		sum(tra.qty) as Legs,
		count(tra.symbol) as Symbols,
		tra.Date,
		sum(tra.Value) as StartValue,
		tra.uTradeSeqNo
	FROM TastyTransactions tra 
		LEFT JOIN TastyTrades trd on tra.TradeNo=trd.TradeNo
	WHERE  ( (tra.action like '%OPEN') or (tra.InstrumentType='Future' and tra.Type='Trade' and tra.AvePrice=0) )  and trd.TradeNo is NULL
	GROUP BY tra.TradeNo,tra.uTradeSeqNo, tra.Date, tra.uSymbol,left(tra.InstrumentType,6);

    -- update trade stats
	exec dbo.ClassifyTastyTrades;


	--find matching closing transactions
	DECLARE @Symbol as varchar(50),
	@tradeNo as int,
	@TradeDate as datetime,
	@OpenningQty as int,
	@TransactionId as int,
	@ClosingQty as int,
	@RemainingOpenQty as int


	-- loop through all openning trades that were not closed yet
	DECLARE ot_cursor CURSOR FOR 
		SELECT ot.Symbol, ot.TradeNo, ot.Date, ot.Qty * coalesce(multiplier,1)        --instead of Qty use Multiplier * qty so that the qty is in number of shares, and we have the same units for options and shares 
 		 FROM TastyTransactions ot LEFT JOIN TastyTrades ON ot.TradeNo=TastyTrades.TradeNo  
		WHERE ( (ot.action like '%OPEN') or (ot.InstrumentType='Future' and ot.Type='Trade' and ot.AvePrice=0) )  and TastyTrades.EndDate is null      
		ORDER BY ot.tradeNo, ot.Symbol       
	OPEN ot_cursor ;
	FETCH NEXT FROM ot_cursor  INTO @Symbol, @TradeNo, @TradeDate, @OpenningQty
	WHILE @@FETCH_STATUS = 0
		BEGIN
			
			SET @RemainingOpenQty=@OpenningQty 
			-- loop through all closing trades that were not matched yet to openning trades
			DECLARE ct_cursor CURSOR FOR
				SELECT TransactionId, case when type='Money Movement' then 0 else Qty* coalesce(multiplier,1) end FROM TastyTransactions  --set futures money movements to zero qty, they are just mark to market adjustments not closing transactions
				WHERE Symbol=@Symbol AND  Date>=@TradeDate and tradeNo is null 
				 and ( (action like '%CLOSE' or Description like 'Removal%') or (InstrumentType='Future' and type='Money Movement') or (InstrumentType='Future' and type='Trade' and AvePrice<>0)) 
				ORDER BY Date asc
			OPEN ct_cursor
			FETCH NEXT FROM ct_cursor  INTO @TransactionId, @ClosingQty
			WHILE @@FETCH_STATUS = 0 AND @RemainingOpenQty>0
				BEGIN
					UPDATE TastyTransactions SET TradeNo=@TradeNo WHERE TransactionId =@TransactionId; -- match the closing leg on the trade with openning leg				
					SET @RemainingOpenQty = @RemainingOpenQty-@ClosingQty   --reduce the remaining symbol quantity
					FETCH NEXT FROM ct_cursor  INTO @TransactionId, @ClosingQty
				END
			CLOSE ct_cursor;
			DEALLOCATE ct_cursor;

			FETCH NEXT FROM ot_cursor  INTO @Symbol, @TradeNo, @TradeDate, @OpenningQty
		END
	CLOSE ot_cursor;
	DEALLOCATE ot_cursor;



	--update closed orders information: endDTE, endValue, Commisions, Fees
	with closedOrders  -- select closed orders that have not been updated yet
	as
	(
		SELECT tra.tradeNo, sum(tra.Value) as tradeValue, sum(tra.Commissions) as Commissions, sum(tra.Fees) as Fees,
		max(tra.Date) as endDate,min(datediff(day,tra.Date,tra.ExpDate)) as endDTE
		FROM TastyTransactions tra left join TastyTrades trd on tra.tradeNo=trd.tradeNo
		WHERE trd.EndDate is null
		GROUP BY tra.tradeNo
		HAVING sum(case when action like '%OPEN' then Qty when tra.InstrumentType='Future' and tra.type='Trade' and tra.AvePrice =0 then Qty when action like '%CLOSE' or Type='Receive Deliver' then -Qty when  tra.InstrumentType='Future' and tra.AvePrice <>0 and tra.Type ='Trade'   then -Qty else 0 end)=0    --closed trades
	)
	UPDATE t
	set t.EndDTE=closedOrders.endDTE,
	t.EndDate=closedOrders.endDate,
	t.EndValue=closedOrders.tradeValue-t.StartValue, -- substract the openning value
	t.Commissions=closedOrders.Commissions,
	t.Fees=closedOrders.Fees

	FROM TastyTrades t INNER JOIN closedOrders  ON t.tradeNo =closedOrders.tradeNo;




	--update distance from previous trade measured in minutes between last leg of previous trade and first leg of new trade
	UPDATE nt
	SET DistFromPrevTradeDays=datediff(day,pt.StartDate,nt.StartDate)
	FROM dbo.TastyTrades nt inner join dbo.TastyTrades pt on nt.uTradeSeqNo=pt.uTradeSeqNo+1 and nt.uSymbol =pt.uSymbol ;

	--update link between trades
	exec  dbo.LinkTastyTrades;




	
	END

GO
