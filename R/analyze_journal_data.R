# Steps:
# 
# 1. Scrap meta data from journal websites
#       parse.aer.volume
# 2. Download data appendices
# 3. Analyse data appendices and generate meta data 
# 4. Generate html sites

write.articles.jel.csv = function(dt = read.complete.data()) {
  head(dt$JEL1)  
  
  li = lapply(1:7, function(j) {
    jel.col = paste0("JEL",j)
    dt[["JEL"]]
    str = str.trim(dt[[jel.col]])
    str = gsub("JEL Codes:","",str,fixed=TRUE)
    rows= has.substr(str,":")
    str[rows] = str.trim(str.left.of(str[rows],":"))
    rows = nchar(str)>3
    str[rows] = ""
    rows = nchar(str)>0
    ret = rbind(
      data.table(id=dt$id,jel=str),
      data.table(id=dt$id,jel=substring(str,1,2)),
      data.table(id=dt$id,jel=substring(str,1,1))
    )
    ret = ret[nchar(ret$jel)>0,]
    ret = unique(ret)
    ret
  })
  jdt = rbindlist(li)
  ord = order(nchar(jdt$jel), jdt$jel)
  jdt = jdt[ord,]
  write.csv(jdt, file=paste0(main.dir,"/jel_of_articles.csv"), row.names=FALSE )
}

read.articles.jel.csv = function() {
  dt = fread(paste0(main.dir,"/jel_of_articles.csv"))
  setkey(dt,jel,id)
  dt
}


write.complete.data = function() {
  restore.point("write.complete.data")
  files = list.files(dcsv.dir, full.names=TRUE)
  li = lapply(files, read.csv, stringsAsFactors=FALSE)
  dt = rbindlist(li)
   
  file = paste0(main.dir,"/complete_journal_data.csv")
  write.csv(dt,file, row.names=FALSE)
}
read.complete.data = function() {
  file = paste0(main.dir,"/complete_journal_data.csv")
  as.data.frame(fread(file))
  #read.csv(file, stringsAsFactors=FALSE)
}

get.journal.info = function(journ) {
  ji = jis[[journ]]
  
  csv.files = list.files(csv.dir, pattern = paste0(journ,"_.*"))
  csv.vols = as.numeric(str.left.of(str.right.of(csv.files,"_vol_"),".csv"))
  
  dcsv.files = list.files(dcsv.dir, pattern = paste0(journ,"_.*"))
  dcsv.vols = as.numeric(str.left.of(str.right.of(dcsv.files,"_vol_"),".csv"))
  
  cur.year = year(Sys.time())
  cur.vol = cur.year - ji$first_year + ji$first_vol

  c(ji, nlist(csv.files,csv.vols,dcsv.files, dcsv.vols, cur.year, cur.vol))
}

get.all.vol = function(journ) {
  ji = get.journal.info(journ)
  ji$first_vol:ji$cur.vol
}

get.current.vol = function(journ) {
  get.journal.info(journ)$cur.vol
}

get.all.journals = function() {
  names(jis)
}

examples.apply.to.vol = function() {
  get.all.vols("aer")
  init.journal.scrapper()

  #ret = apply.to.vol(vol=get.all.vol("aer"),journ="aer", fun= download.article.pdf)
  ret = apply.to.vol(vol=get.all.vol("aer"),journ="aer", fun= convert.article.to.txt)

  
  ret = apply.to.vol(vol=get.all.vol("aer"),journ="aer", fun= download.article.data.zip)
  ret = apply.to.vol(vol=get.all.vol("aer"),journ="aer", fun= create.article.files.csv)
  ret = apply.to.vol(vol=104,journ="aer", fun= summarize.article.files.csv)
}

apply.to.vol = function(vol=get.current.vol(journ),journ, fun, vol.dt=NULL,...) {
  if (length(vol)>1) {
    li = lapply(vol, apply.to.vol, journ=journ, fun=fun,vol.dt=vol.dt, ...)
    return(do.call("c",li))
  }
  restore.point("apply.to.vol")
  if (is.null(vol.dt))
    vol.dt=load.vol.dt(journ,vol)
  if (length(vol.dt)==0)
    return(NULL)
  li = lapply(1:NROW(vol.dt),function(i) {
    cat(".")
    try(fun(d=vol.dt[i,],...))
  })
  li
}

load.vol.dt = function(journ, vol) {
  file = paste0(journ,"_vol_",vol,".csv")
  tryCatch( vol.dt <- read.csv(paste0(csv.dir,"/",file)))

  vol.dt
}


examples.scrap.journal.web.data = function() {
  init.journal.scrapper()
  scrap.journal.web.data(journ="aer")
  #scrap.journals.web.data()
}


scrap.journal.web.data = function(journ, overwrite=FALSE, verbose=TRUE) {
  #journ = "aer"
  restore.point("scrap.journal.web.data")
  ji = get.journal.info(journ)
  
  if (!overwrite) {
    vols = c(setdiff(ji$first_vol:ji$cur.vol, ji$csv.vols), max(ji$csv.vols))
  } else { 
    vols = ji$first_vol:ji$cur.vol
  }
    
  # vol = vols[2]
  for (vol in vols) {
    if (verbose)
      cat("parse.journal.volume(journ=",journ,", vol=",vol,")")
    parse.journal.volume(journ=journ, vol=vol)
  }
}

init.journal.scrapper = function(
      base.dir = "D:/libraries/EconJournalData",
      base.data.dir = "D:/data/EconJournalData",
      issues_html.dir = paste0(base.data.dir,"/issues_html"),  
      html.dir = paste0(base.data.dir,"/html"),
      csv.dir = paste0(base.dir,"/csv"),
      dcsv.dir = paste0(base.dir,"/detailed_csv"),
      data.dir = paste0(base.data.dir,"/zipdata"),
      main.dir = base.dir
    ) {

  
  jis = load.jis(file = paste0(base.dir,"/journal_info.yaml"))
  jel <- read.csv(paste0(base.dir,"/jel_codes.csv"), stringsAsFactors=FALSE)
  jel$digits <- nchar(jel$code)
  jel$name = paste0(jel$code,": ", jel$label)
  rows = jel$digits==1
  jel$name[rows] = gsub(": General","",jel$name[rows],fixed=TRUE)
  jel.codes = jel
  
  tags.csv = read.csv(paste0(base.dir,"/tags.csv"), stringsAsFactors=FALSE)
  
  li = nlist(jel.codes, tags.csv, base.dir, base.data.dir, issues_html.dir, html.dir, csv.dir, dcsv.dir, data.dir, main.dir, jis)
  
  copy.into.env(source=li, dest=globalenv())

}

analyze.journals = function() {
  setwd("D:/libraries/EconJournalData")
  init.journal.scrapper()
  
  files = list.files(csv.dir, full.names=TRUE)
  li = lapply(files, read.csv, stringsAsFactors=FALSE)

  dt = rbindlist(li)
  library(dplyr)
  dt$data.url[1:10]
  df = as.data.frame(dt)
  #df = automatic.type.conversion(df)
  d = df %>%
    filter(!is.na(data.size)) %>%
    filter(data.size>0.01) %>%    
    arrange(desc(data.size))
  
  summary(d$data.size)
  d
  file = "articles.html"
  make.html(d,file)
  browseURL(paste0("file://", getwd(), "/",file))

  file="jel_articles.html"
  make.JEL.html(d, file=file)
  browseURL(paste0("file://", getwd(), "/",file))
  
}

robust.rbindlist = function(li) {
  restore.point("robust.rbindlist")
  
  not.null = !sapply(li, is.null)
  li = li[not.null]
  cols = Reduce(intersect,lapply(li, function(li) names(li)) )
  ili = lapply(li, function(li) li[cols])
  rbindlist(ili)
}

file_ext = function (x) 
{
    pos <- regexpr("\\.([[:alnum:]]+)$", x)
    ifelse(pos > -1L, substring(x, pos + 1L), "")
}


parse.journal.volume = function(journ, vol=103, issues = 1:12, articles=1:100,  ji = get.journal.info(journ)) {
  restore.point("parse.journal.volume")
  
  if (!is.finite(vol))
    stop("Non finite vol")
  
  # Check if a manual function exists
  fun = paste0("parse.",ji$webtype,".volume")
  
  if (!exists(fun))
    fun = "parse.default.volume"
  
  li = do.call(fun, list(journ=journ, vol=vol, issues=issues, articles=articles))
  bind_rows(li)
}

examples.parse.default.volume = function() {
  init.journal.scrapper()
  #parse.default.volume(journ="aer", vol = 104, issues=9)
  
  dt = parse.default.volume(journ="aer", vol = 104, issues=9, write.csv = FALSE)
  
}

parse.default.volume = function(journ, vol=103, issues = 1:12, articles=1:100,  ji = get.journal.info(journ), verbose=TRUE, write.csv = TRUE) {
  restore.point("parse.default.volume")
  
  
  fun.issue.urls = get(paste0(ji$webtype,".issue.urls"))
  fun.parse.article = get(paste0("parse.",ji$webtype,".article"))
  
  issue = issues[1]
  
  #issue = 1
  articleNum = 1
  li = NULL
  
  counter = 1
  page.ind = 1
  ignore.issues = NULL
  
  articleNum = 1
  #articleNum = 10
  for (issue in setdiff(issues, ignore.issues)) {
    urls = fun.issue.urls(journ=journ,vol=vol,issue=issue)
    for (articleNum in intersect(seq_along(urls),articles)) {
      d.ind = list(journ=journ,issue=issue, vol=vol, issue=issue, articleNum=articleNum, url=urls[articleNum])    
      d = fun.parse.article(d.ind)
      if (verbose) {
        cat(paste0("parse ", journ, ".", vol, ".", issue, ".",articleNum, ifelse(d$exist,": ","does not exist! : ")))
      }
      if (d$exists) {
        li[[counter]] = d
        counter = counter+1
        cat(d$title," (",d$data.size, " ", d$data.unit,")\n")
      }
    }
  }
  dt = parsed.articles.li.to.table(li)
  if (write.csv)
    write.journal.vol.csv(dt, journ=journ, vol=vol)
  dt
}


parsed.articles.li.to.table = function(li) {
  restore.point("parsed.articles.li.to.table")
  
  if (length(li)==0) return()
  
  dt = as.data.frame(do.call("rbind",li))
  for (col in colnames(dt)) {
    dt[,col] = unlist(dt[,col])
  }
  dt = as.data.table(dt)
  if (length(li)==0)
    return(NULL)
  
  rows = which(nchar(dt$title)==0)
  if (length(rows)>0)
    dt$title[rows] = "Unknown Title"
  dt$JEL = paste(dt$JEL1,dt$JEL2,dt$JEL3,dt$JEL4,dt$JEL5,dt$JEL6,dt$JEL7, sep=", ")
  
  dt$data.size = as.numeric(dt$data.size)
  rows = which(dt$data.unit=="GB")
  if (length(rows)>0) {
    dt$data.size[rows] = dt$data.size[rows]*1000
    dt$data.unit[rows] = "MB"
  }
  rows = which(dt$data.unit=="bytes")
  if (length(rows)>0) {
    dt$data.size[rows] = dt$data.size[rows] / (1000*1000)
    dt$data.unit[rows] = "MB"
  }
  if (is.null(dt$keywords))
    dt$keywords = ""

  if (is.null(dt$publication.date))
    dt$publication.date = NA

  if (is.null(dt$has.data))
    dt$has.data = dt$data.size > 0
  
  dt$id = paste0(dt$journ,"_",dt$vol,"_",dt$issue,"_",dt$articleNum)

  library(dplyr)
  dt = select(dt,id,journ,vol,issue,articleNum,title,has.data,url, article.url, data.url, htmlFile,publication.date,data.size,data.unit,keywords,JEL,JEL1,JEL2,JEL3,JEL4,JEL5,JEL6,JEL7)
  dt
}

