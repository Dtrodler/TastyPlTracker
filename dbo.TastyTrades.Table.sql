USE [OPTIONS]
GO
/****** Object:  Table [dbo].[TastyTrades]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TastyTrades](
	[TradeNo] [int] NOT NULL,
	[TradeDescription] [varchar](100) NULL,
	[ParentTradeNo] [int] NULL,
	[TopParentTradeNo] [int] NULL,
	[uSymbol] [varchar](50) NULL,
	[Category] [varchar](100) NULL,
	[InstrumentType] [varchar](15) NULL,
	[StartDTE] [int] NULL,
	[EndDTE] [int] NULL,
	[Legs] [int] NULL,
	[Symbols] [int] NULL,
	[StartDate] [datetime] NULL,
	[EndDate] [datetime] NULL,
	[StartValue] [decimal](10, 2) NULL,
	[EndValue] [decimal](10, 2) NULL,
	[Commissions] [decimal](15, 4) NULL,
	[Fees] [decimal](15, 4) NULL,
	[NoOfAdjustments] [int] NULL,
	[MarketDirection] [varchar](50) NULL,
	[RiskType] [varchar](25) NULL,
	[ProfitType] [varchar](25) NULL,
	[uTradeSeqNo] [int] NULL,
	[DistFromPrevTradeDays] [int] NULL,
	[TradeValue]  AS ([StartValue]+[EndValue]),
	[TotalTradeValue]  AS ((([StartValue]+[EndValue])+[Commissions])+[Fees]),
	[TradeLengthDays]  AS (datediff(day,[StartDate],[EndDate])),
 CONSTRAINT [PK_TastyTransactionsClosedTrades] PRIMARY KEY CLUSTERED 
(
	[TradeNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
