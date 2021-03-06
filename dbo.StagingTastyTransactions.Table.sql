USE [OPTIONS]
GO
/****** Object:  Table [dbo].[StagingTastyTransactions]    Script Date: 7/25/2020 12:36:26 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StagingTastyTransactions](
	[Date] [varchar](50) NOT NULL,
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
	[OptType] [varchar](5) NULL
) ON [PRIMARY]
GO
