import os, time, dlt, requests
from requests.adapters import HTTPAdapter
from urllib3.util import Retry
BASKET = {"PLD":"industrial","EGP":"industrial","FR":"industrial","STAG":"industrial","TRNO":"industrial","REXR":"industrial","SPG":"retail","KIM":"retail","REG":"retail","FRT":"retail","BRX":"retail","NNN":"retail","O":"retail","ADC":"retail","BXP":"office","VNO":"office","KRC":"office","HIW":"office","CUZ":"office","DEI":"office","SLG":"office","EQR":"residential","AVB":"residential","ESS":"residential","UDR":"residential","MAA":"residential","CPT":"residential","INVH":"residential","AMH":"residential","WELL":"healthcare","VTR":"healthcare","DOC":"healthcare","OHI":"healthcare","EQIX":"data_center","DLR":"data_center","AMT":"tower","CCI":"tower","PSA":"storage","EXR":"storage","CUBE":"storage","HST":"hotel","PK":"hotel","RHP":"hotel","VICI":"gaming_netlease","GLPI":"gaming_netlease","WPC":"gaming_netlease","EPR":"specialty","IRM":"specialty","LAMR":"specialty","SBAC":"tower","ARE":"life_science","MPT":"healthcare"}
CONCEPTS = ["Assets","OperatingIncomeLoss","Revenues","InterestExpense","InterestExpenseDebt","InterestExpenseNonoperating","InterestAndDebtExpense","DepreciationDepletionAndAmortization","DepreciationAndAmortization","DepreciationAmortizationAndAccretionNet","RealEstateInvestmentPropertyDepreciation","LongTermDebt","LongTermDebtNoncurrent","LongTermDebtCurrent","DebtInstrumentCarryingAmount","DebtAndCapitalLeaseObligations","SecuredDebt","UnsecuredDebt","UnsecuredLongTermDebt","NotesPayable","LongTermNotesPayable","SeniorNotes","LineOfCredit","CashAndCashEquivalentsAtCarryingValue","NetIncomeLoss","IncomeTaxExpenseBenefit","IncomeLossFromContinuingOperationsBeforeIncomeTaxesExtraordinaryItemsNoncontrollingInterest"]
FORMS = {"10-K","10-Q","10-K/A","10-Q/A"}
S = requests.Session()
S.headers["User-Agent"] = os.environ["SEC_USER_AGENT"]
S.mount("https://", HTTPAdapter(max_retries=Retry(total=5, backoff_factor=1, status_forcelist=[429,500,502,503,504])))
def get(url):
 time.sleep(0.12)
 r = S.get(url, timeout=60)
 r.raise_for_status()
 return r.json()
@dlt.resource(name="companies", write_disposition="replace", primary_key="cik")
def companies():
 m = {v["ticker"]: v for v in get("https://www.sec.gov/files/company_tickers.json").values()}
 for t, s in BASKET.items():
  if t in m: yield {"ticker": t, "cik": m[t]["cik_str"], "name": m[t]["title"], "subsector": s}
  else: print(f"WARN: {t} not in SEC ticker map, skipped")
@dlt.transformer(data_from=companies, name="facts", write_disposition="merge", primary_key="fact_key")
def facts(co):
 d = get(f"https://data.sec.gov/api/xbrl/companyfacts/CIK{int(co['cik']):010d}.json")["facts"].get("us-gaap", {})
 for c in CONCEPTS:
  for r in d.get(c, {}).get("units", {}).get("USD", []):
   if r["form"] in FORMS: yield {"fact_key": f"{co['cik']}|{c}|{r.get('start','')}|{r['end']}|{r['accn']}", "cik": co["cik"], "ticker": co["ticker"], "concept": c, "period_start": r.get("start"), "period_end": r["end"], "val": r["val"], "accn": r["accn"], "fy": r.get("fy"), "fp": r.get("fp"), "form": r["form"], "filed": r["filed"], "frame": r.get("frame")}
@dlt.source(name="sec_edgar")
def sec_edgar(): return companies, facts, filings
@dlt.transformer(data_from=companies, name="filings", write_disposition="merge", primary_key="filing_key")
def filings(co):
 f = get(f"https://data.sec.gov/submissions/CIK{int(co['cik']):010d}.json")["filings"]["recent"]
 for fm, a, d, r in zip(f["form"], f["accessionNumber"], f["filingDate"], f["reportDate"]):
  if fm in FORMS: yield {"filing_key": f"{co['cik']}|{a}", "accn": a, "cik": co["cik"], "ticker": co["ticker"], "form": fm, "filing_date": d, "report_date": r}
