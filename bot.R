rm(list = ls())

# pacotes
library(feedeR)
library(magrittr)
library(lubridate)
library(readr)
library(dplyr)
library(twitteR)
library(urlshorteneR)

# carregar keys e oauth
# twitter
api_key <- Sys.getenv("twitter_api_key")
api_secret <- Sys.getenv("twitter_api_secret")
access_token <- Sys.getenv("twitter_access_token")
access_token_secret <- Sys.getenv("twitter_access_token_secret")
setup_twitter_oauth(api_key,api_secret,access_token,access_token_secret)

# goo.gl
goo_gl_key = Sys.getenv("goo_gl_key")
goo_gl_secret = Sys.getenv("goo_gl_secret")
load("/home/sillas/R/Projetos/rbloggers-BR/googl_token")


# Parsear RSS, baixar posts publicados e criar um dataframe com posts novos (df.posts.novos)
# carregar posts ja usados no bot
df.posts.antigos <- read.csv2("/home/sillas/R/Projetos/rbloggers-BR/posts.csv")

sites <- c("Paixão por Dados" = "http://sillasgonzaga.github.io/feed.xml",
           "R, Python e Redes" = "http://neylsoncrepalde.github.io/feed.xml",
           "Symposio" = "https://blog.symposio.com.br/feed",
           "Sociais e Métodos" = "https://sociaisemetodos.wordpress.com/feed/",
           "Cantinho do R" = "https://cantinhodor.wordpress.com/feed/",
           #"Urban Demographics" = "http://feeds.feedburner.com/UrbanDemographics",
           "Análise Macro" = "http://feeds.feedburner.com/analisemacro",
           "Wilson Freitas" = "http://wilsonfreitas.github.io/feeds/rss.xml",
           #"UniversoGEO" = "http://universogeo.org/feed/",
           "Thiago dos Santos" = "http://thiagodossantos.com/feed/",
           "pRodução animal" = "https://producaoanimalcomr.wordpress.com/feed/",
           #"Pedro Albuquerque" = "http://pedrounb.blogspot.com/feeds/posts/default",
           "Metodologia em Ciência Política" = "http://metodologiapolitica.com/feed/",
           "Geo Independência" = "https://geoind.wordpress.com/feed/",
           "Estatística é com R" = "http://www.estatisticacomr.uff.br/?feed=rss2",
           "Dendro Blog" = "http://labdendro.com/blog/feed/",
           "Dados aleatórios" = "http://feeds.feedburner.com/DadosAleatrios",
           "IBPAD" = "http://www.ibpad.com.br/blog/analise-de-dados/feed/",
           "Curso-R" = "http://curso-r.com/index.xml"
           )

safe_feed_extract <- safely(feed.extract)

lista.feed <- sites %>%
  map(safe_feed_extract, encoding = "UTF-8") %>%
  transpose() %>%
  .$result

sites_com_erro <- lista.feed %>% keep(is.null)
lista.feed <- lista.feed %>% discard(is.null)

# o objeto lista.feed é uma lista composta de múltiplas listas
# criar uma lista apenas de data frames

lista.dfs <- list(rep(NA, length(sites)))

for (i in 1:length(lista.feed)) {
  # se erro, pule o blog
  if (inherits(lista.feed[[i]], "try-error")) {
    next
  }
  
  # criar data frame com três variáveis:
  # nome_blog, #titulo_post, #link, #data_post
  blog <- lista.feed[[i]]$items
  # No blogpost, title é na verdade title.text:
  names(blog)[names(blog) == "title.text"] <- "title"
  nome_blog <- names(sites)[i]
  lista.dfs[[i]] <- data.frame(nome_blog = nome_blog,
                               titulo_post = blog$title,
                               link = blog$link,
                               data_post = blog$date,
                               hash = blog$hash,
                               stringsAsFactors = FALSE)
}

df.posts <- bind_rows(lista.dfs)

# PARSEAR STACK OVERFLOW BR
# so <- "https://pt.stackoverflow.com/feeds/tag?tagnames=r&sort=newest"
# so %<>% feed.extract()
# so <- so[["items"]]
# so %<>% mutate(nome_blog = "StackOverflowBR")

so <- "https://pt.stackoverflow.com/feeds/tag?tagnames=r&sort=newest" %>%
  feed.extract() %>%
  .[["items"]] %>%
  mutate(nome_blog = "StackOverflowBR")
# renomear colunas do so para ficar igual ao df.posts
so %<>% select(nome_blog, titulo_post = title.text, link = link,
               data_post = date, hash = hash)

# mergir com df de blog posts
df.posts %<>% rbind(so)

# achar posts e perguntas SO que nao estao presentes 
df.posts.novos <- subset(df.posts, !(hash %in% df.posts.antigos$hash))

# salvar posts
write.table(df.posts, file = "/home/sillas/R/Projetos/rbloggers-BR/posts.csv", sep = ";", row.names = FALSE, append = FALSE)


# criar função de template de tweet
template.tweet <- function(data) {
  nome <- data[["nome_blog"]]
  titulo <- data[["titulo_post"]]
  link <- data[["link_curto"]]
  msg <- paste0(nome, ": ", titulo)
  msg <- substr(msg, 1, 100)
  msg <- paste0(msg, ". ", link, " #rstats")
  return(msg)
}

# classificar de acordo com a data do post
df.posts.novos %<>% arrange(data_post)



# executar codigo apenas se nrow(df.posts.novos) > 0
if (nrow(df.posts.novos) > 0) {
  
  # encurtar link
  df.posts.novos$link_curto <- NA
  for (i in 1:nrow(df.posts.novos)) {
    df.posts.novos$link_curto[i] <- googl_LinksShorten(df.posts.novos$link[i])$id
    }
  print("Ok")
  
  for (i in 1:nrow(df.posts.novos)) {
    x <- df.posts.novos[i, ]
    msg <- template.tweet(x)
    tweet(msg)
    Sys.sleep(10) # adicionar 10 seg de delay pro twitter nao bloquear o bot
  }
}

### salvar log
posts <- nrow(df.posts.novos)
horario <- Sys.time()
msg.log <- sprintf("%s. Quantidade de posts twittados: %s \n", horario, posts)

fileConn <- file("/home/sillas/R/Projetos/rbloggers-BR/log.txt", open = "a")
cat(msg.log, file = fileConn, sep = "")
close(fileConn)



rm(list = ls())
