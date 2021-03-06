USE [OPTIONS]
GO
/****** Object:  Table [dbo].[TastyTransactions]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TastyTransactions](
	[TransactionId] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NOT NULL,
	[Type] [varchar](20) NOT NULL,
	[Action] [varchar](15) NULL,
	[Symbol] [varchar](25) NULL,
	[InstrumentType] [varchar](15) NULL,
	[Description] [varchar](100) NULL,
	[Value] [decimal](15, 4) NULL,
	[Qty] [int] NOT NULL,
	[AvePrice] [decimal](15, 4) NULL,
	[Commissions] [decimal](15, 4) NULL,
	[Fees] [decimal](10, 4) NULL,
	[Multiplier] [int] NULL,
	[UnderlyingSymbol] [varchar](6) NULL,
	[ExpDate] [date] NULL,
	[Strike] [decimal](8, 2) NULL,
	[OptType] [varchar](5) NULL,
	[uSymbol]  AS (case when [InstrumentType]='Future' then left([symbol],len([symbol])-(2)) else replace(rtrim(case when patindex('% %',[symbol])>(0) then left([symbol],patindex('% %',[symbol])) else [symbol] end),'.','') end) PERSISTED,
	[tradeNo] [int] NULL,
	[uTradeSeqNo] [int] NULL,
	[OrigQty] [int] NULL,
	[OrigDate] [datetime] NULL,
 CONSTRAINT [PK_TastyTransactions] PRIMARY KEY CLUSTERED 
(
	[TransactionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
