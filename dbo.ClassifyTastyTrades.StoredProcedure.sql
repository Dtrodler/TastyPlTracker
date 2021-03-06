USE [OPTIONS]
GO
/****** Object:  StoredProcedure [dbo].[ClassifyTastyTrades]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		DT
-- Create date: 
-- Description:	Determines trade category and description for tasty trades based on trade legs
-- =============================================
CREATE PROCEDURE [dbo].[ClassifyTastyTrades] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

declare @Category as varchar(40),
@TradeDescription as varchar(100),
@RiskType as varchar(25),
@ProfitType as varchar(25),
@TradeNo as int,
@Qty as int,
@TotalTradeQty as int,
@OptType as varchar(5),
@Strike as decimal(8,1),
@DTE as int,
@Symbol as varchar(25),
@PrevOptType as varchar(5),
@RowNoTrade as int,
@MaxRowNoTrade as int,
@expNo as int,
@expNoPrev as int,
@Action as char(1),
@Type as varchar(50),
@InstrumentType as varchar(50),
@NoOfSoldPuts as int,
@NoOfBoughtPuts as int,
@NoOfSoldCalls as int,
@NoOfBoughtCalls as int,
@NoOfSoldFutures as int,
@NoOfBoughtFutures as int


SET @Category=''
SET @TradeDescription =''
SET @RiskType =''
SET @ProfitType =''
SET @expNoPrev=0
SET @prevOptType=''

DECLARE t_cursor CURSOR FOR
SELECT case when [Action] like '%BUY%' then 'B' when action like '%SELL%' then 'S' end as Action 
	 ,[Type]
	 ,ttr.[InstrumentType]
     ,[Qty]
	 ,sum(qty) over (partition by ttr.TradeNo) as TotalTradeQty
     ,[OptType]
	 ,[Strike]
	 ,datediff(day,Date,[ExpDate]) as DTE
	 ,[Symbol]
     ,ttr.[tradeNo]
	 ,row_Number() over (partition by ttr.TradeNo order by ttr.InstrumentType, ExpDate, OptType, Strike desc) as RowNoTrade   
	 , count(*) over (partition by ttr.TradeNo) as MaxRowNoTrade
	 ,dense_rank() over (partition by ttr.TradeNo order by ttr.InstrumentType,ExpDate) as expNo,
	 sum(case when action like '%BUY%' and optType='PUT' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfBoughtPuts,
	 sum(case when action like '%BUY%' and optType='CALL' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfBoughtCalls,
	 sum(case when action like '%SELL%' and optType='PUT' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfSoldPuts,
	 sum(case when action like '%SELL%' and optType='CALL' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfSoldCalls,	  
	 sum(case when action like '%SELL%' and ttr.InstrumentType ='Future' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfSoldFutures,	  
	 sum(case when action like '%BUY%' and ttr.InstrumentType ='Future' then Qty else 0 end) over (Partition by ttr.TradeNo) as NoOfBoughtFutures	
 
FROM [dbo].[TastyTransactions] ttr left join [dbo].[TastyTrades] tt on ttr.tradeNo =tt.TradeNo  where (action like '%OPEN%' or (ttr.InstrumentType='Future' and ttr.Type='Trade' and ttr.AvePrice=0)) and tt.category is null
ORDER BY ttr.TradeNo, RowNoTrade
 
OPEN t_cursor
FETCH NEXT FROM t_cursor INTO @Action,@Type, @InstrumentType, @Qty,@TotalTradeQty, @OptType, @Strike, @DTE, @Symbol, @TradeNo,@RowNoTrade,@MaxRowNoTrade,@expNo,
@NoOfBoughtPuts, @NoOfBoughtCalls, @NoOfSoldPuts,@NoOfSoldCalls, @NoOfSOldFutures, @NoOfBoughtFutures
WHILE @@FETCH_STATUS = 0
	BEGIN

		IF @expNo<>@expNoPrev and @expNo=1 and @DTE is not null
		BEGIN
			SET @TradeDescription = @TradeDescription +' @'+cast(@expNo as varchar(2)) + '('+cast(@DTE as varchar(3)) + '): ';
			SET @prevOptType='';
		END 

		IF @expNo<>@expNoPrev and @expNo<>1
		BEGIN
			SET @Category = @Category +' @'+cast(@expNo as varchar(2)) +': ';
			SET @TradeDescription = @TradeDescription +' @'+cast(@expNo as varchar(2)) + '('+cast(@DTE as varchar(3)) + '): ';
			SET @prevOptType='';
		END 

		if @OptType ='PUT' and @PrevOptType <>'PUT'
		BEGIN
			SET @Category =@Category +' | ';
			SET @TradeDescription =@TradeDescription +' | ';
		END

		IF @Action ='B' and (@OptType ='PUT' or @OptType ='CALL')
		BEGIN
			SET @Category =@Category  +'+'+ cast(@Qty as varchar(2));
			SET @TradeDescription =@TradeDescription  +'+'+ cast(@Qty as varchar(2)) +'('+cast(@Strike as varchar(8))+')';
		END
		ELSE IF @Action ='S' and (@OptType ='PUT' or @OptType ='CALL')
		BEGIN
			SET @Category =@Category +'-' + cast(@Qty as varchar(2));
			SET @TradeDescription =@TradeDescription  +'-'+ cast(@Qty as varchar(2)) +'('+cast(@Strike as varchar(8))+')';
		END

		IF @Type='Receive Deliver' and @InstrumentType ='Equity'
		BEGIN
			IF @Action ='B'
			BEGIN
				SET @Category ='ASSIGNED LONG SHARES '
				SET @TradeDescription ='ASSIGNED LONG SHARES ' + cast(@TotalTradeQty as varchar(4))
			END
			IF @Action ='S'
			BEGIN
				SET @Category ='ASSIGNED SHORT SHARES ' 
				SET @TradeDescription ='ASSIGNED SHORT SHARES ' + cast(@TotalTradeQty as varchar(4))
			END
			SET @RiskType ='NA'
			SET @ProfitType ='NA'
		END

		IF @Type='Trade' and @InstrumentType ='Equity'
		BEGIN
			IF @Action ='B'
			BEGIN
				SET @Category ='BOUGHT SHARES ' + cast(@TotalTradeQty as varchar(4))
				SET @TradeDescription ='BOUGHT SHARES ' + cast(@TotalTradeQty as varchar(4))
				SET @RiskType ='UNDEFINED DOWN'
				SET @ProfitType ='UNDEFINED UP'
			END
			IF @Action ='S'
			BEGIN
				SET @Category ='SOLD SHARES ' + cast(@TotalTradeQty as varchar(4))
				SET @TradeDescription ='SOLD SHARES ' + cast(@TotalTradeQty as varchar(4))
				SET @RiskType ='UNDEFINED UP'
				SET @ProfitType ='UNDEFINED DOWN'
			END
			
		END

		IF @Type='Receive Deliver' and @InstrumentType ='Future'
		BEGIN
			IF @Action ='B'
			BEGIN
				SET @Category ='ASSIGNED LONG FUTURE '
				SET @TradeDescription ='ASSIGNED LONG FUTURE ' + cast(@TotalTradeQty as varchar(4))
			END
			IF @Action ='S'
			BEGIN
				SET @Category ='ASSIGNED SHORT FUTURE ' 
				SET @TradeDescription ='ASSIGNED SHORT FUTURE ' + cast(@TotalTradeQty as varchar(4))
			END
			SET @RiskType ='NA'
			SET @ProfitType ='NA'
		END

		IF @Type='Trade' and @InstrumentType ='Future'
		BEGIN
			IF @Action ='B'
			BEGIN
				SET @Category =@Category  +' +'+ cast(@Qty as varchar(2)) +@Symbol;
				SET @TradeDescription =@TradeDescription  +' +'+ cast(@Qty as varchar(2)) +@Symbol;
			END
			IF @Action ='S'
			BEGIN
				SET @Category =@Category  +' -'+ cast(@Qty as varchar(2)) +@Symbol;
				SET @TradeDescription =@TradeDescription  +' -'+ cast(@Qty as varchar(2)) +@Symbol;
			END
		END


		SET @expNoPrev =@expNo;
		SET @prevOptType=@OptType ;
				
		IF @RowNoTrade =@MaxRowNoTrade 
		BEGIN
			if @NoOfSoldCalls >@NoOfBoughtCalls and @RiskType =''
			BEGIN
				IF @NoOfSoldPuts >@NoOfBoughtPuts
				BEGIN
					set @RiskType ='UNDEFINED UP and DOWN'
				END
				ELSE
				BEGIN 
					set @RiskType ='UNDEFINED UP'
				END 
			END
			if @NoOfSoldCalls <=@NoOfBoughtCalls and @RiskType =''
			BEGIN
				IF @NoOfSoldPuts >@NoOfBoughtPuts
				BEGIN
					set @RiskType ='UNDEFINED DOWN'
				END
				ELSE
				BEGIN 
					set @RiskType ='DEFINED'
				END 
			END			  

			if @NoOfSoldCalls <@NoOfBoughtCalls and @ProfitType =''
			BEGIN
				IF @NoOfSoldPuts <@NoOfBoughtPuts
				BEGIN
					set @ProfitType ='UNDEFINED UP and DOWN'
				END
				ELSE
				BEGIN 
					set @ProfitType ='UNDEFINED UP'
				END 
			END
			if @NoOfSoldCalls >=@NoOfBoughtCalls and @ProfitType =''
			BEGIN
				IF @NoOfSoldPuts <@NoOfBoughtPuts
				BEGIN
					set @ProfitType ='UNDEFINED DOWN'
				END
				ELSE
				BEGIN 
					set @ProfitType ='DEFINED'
				END 
			END		

			if @NoOfSoldFutures <> @NoOfBoughtFutures  and @RiskType=''
			BEGIN
				IF @NoOfSoldFutures > @NoOfBoughtFutures 
				BEGIN
					set @RiskType ='UNDEFINED DOWN'
					set @ProfitType ='UNDEFINED UP'
				END
				ELSE
				BEGIN
					set @RiskType ='UNDEFINED UP'
					set @ProfitType ='UNDEFINED DOWN'
				END
			END



			update dbo.TastyTrades 
			SET Category=@Category, TradeDescription=@TradeDescription , RiskType=@RiskType, ProfitType=@ProfitType  
			WHERE tradeNo=@TradeNo;
			SET @Category ='';
			SET @TradeDescription ='';
			SET @RiskType='';
			SET @ProfitType ='';
			SET @expNoPrev =0;
			SET @prevOptType=''
		END



	
		FETCH NEXT FROM t_cursor INTO @Action,@Type, @InstrumentType, @Qty,@TotalTradeQty, @OptType, @Strike, @DTE, @Symbol, @TradeNo,@RowNoTrade,@MaxRowNoTrade,@expNo,
		@NoOfBoughtPuts, @NoOfBoughtCalls, @NoOfSoldPuts,@NoOfSoldCalls, @NoOfSOldFutures, @NoOfBoughtFutures
	END
CLOSE t_cursor;
DEALLOCATE t_cursor;
END
GO
