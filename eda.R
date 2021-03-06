source(fe.R)

train.whatis <- whatis(train)
head(train.whatis)
test.whatis <- whatis(test)
head(test.whatis)

save(train.whatis, test.whatis, file="eda.rda")

# Is the dataset imbalanced?
hist(y_train)




## Are there States in Allstate?

# When going across categorical variables, one can notice a variable with 51 levels. 
# First thing that comes to mind is that this variable has something to do with 50+DC 
# states of USA (at least it can be a plausible hypothesis). This adds an interesting 
# spatial dimension to the data and allows to look at the dataset in a slightly more 
informed fashion.

```{r, echo=FALSE, warning=FALSE, message=FALSE}

rm(list = ls())

library(data.table)
library(Matrix)
library(xgboost)
library(Metrics)
library(maps)
library(ggplot2)
library(viridis)
library(plotly)

train = fread("../input/train.csv", showProgress = F)
test = fread("../input/test.csv", showProgress = F)

train[, loss:=log(loss)]
test[, loss:=0]
train_ids <- train$id; test_ids <- test$id;
y_train <- train$loss
```

## Bring in the maps

We are going to use the map data available in R under `state.x77` data and map data `state`. The data actually comes from [1977 Statistical Abstract](http://www.census.gov/library/publications/1977/compendia/statab/98ed.html). The publication is slightly inconsistent in recording the data for the District of Columbia, so creator of the `state` dataset decided to omit DC. We will add it back using the actual data from the Statistical Abstract, and reusing Maryland data, where respective information for DC is not available.

```{r}
us_map <- map_data("state")

tmp <- data.frame(region=tolower(rownames(state.x77)), data.frame(state.x77), abb=state.abb, division=state.division, stringsAsFactors = F)
dc_state <- data.frame(region="district of columbia", 
                       Population=712,
                       Income = 5299, 
                       Illiteracy = 0.9,
                       Life.Exp= 70.22, # US Avg
                       Murder= 8.5,
                       HS.Grad=52.3,
                       Frost=101,
                       Area=61,
                       abb="DC", division="South Atlantic")
tmp <- rbind(tmp, dc_state); 
tmp <-tmp[order(tmp$region),]; rownames(tmp) <- NULL
tmp$cat112 <- 1:nrow(tmp)
mapdata=merge(us_map, tmp, by='region')
```

We also need to refactor the categorical data somewhat to be able to merge in the state information. We will use factor order as a guiding principle for assigning the state number.

```{r}

train_test = rbindlist(list(train, test), use.names = T)
features = setdiff(names(train_test), c("id", "loss"))

LETTERS702 <- c(LETTERS, sapply(LETTERS, function(x) paste0(x, LETTERS)))

for (f in features) {
  if (is.character(train_test[[f]]) ) {
    levels <- intersect(LETTERS702, unique(train_test[[f]]))
    train_test[[f]] <- as.integer(factor(train_test[[f]], levels=levels))
  }
}
```

Let's look at the number of observations in the dataset by state on the map. Ok, California is well sampled, as well as some central states.

```{r, echo=FALSE}

mapdata_p1=merge(mapdata,train_test[,.(count=.N), by=.(cat112)],by="cat112")

p1 <- ggplot(data=mapdata_p1, aes(x=long, y=lat, group=group))
p1 <- p1 + geom_polygon(colour="white", aes(fill=count)) + ggtitle("Number of observations by State")
p1 <- p1 +xlab("Longitude") + ylab("Latitude") +  scale_fill_viridis() + theme_bw() 
ggplotly(p1)
```

In order to verify the validate the hypothesis that `cat112` is in fact the state code, one could look at the state population against the number of observations in the dataset (basically testing the assumption that the data is stratified by state). _Please, note that the Population data is from 1977 and therefore we should not expect it to match perfectly._

```{r, echo=FALSE}

tmp2 <- merge(tmp, train_test[,.(count=.N), by=.(cat112)],all.x=T, by=c("cat112"))
t2 <- ggplot(tmp2,aes(x=count, y=Population)) + geom_point(size=3,aes(color=division)) + scale_color_viridis(discrete = T) +geom_smooth(method = lm) + ggtitle("Observation count by state vs. Population")
ggplotly(t2)
```

## Loss by state {.tabset}

We will merge the state data into the main dataset and look at the median loss by state.

```{r, echo=FALSE}

train_test <- merge(train_test, tmp, all.x=T, by=c("cat112"))  

x_train = train_test[train_test$id %in% train_ids,]
x_test = train_test[train_test$id %in% test_ids,]


mapdata_p2=merge(mapdata, x_train[,.(median_loss=median(exp(loss))),, by=.(cat112)],by="cat112")

p2 <- ggplot(data=mapdata_p2, aes(x=long, y=lat, group=group))
p2 <- p2 +xlab("Longitude") + ylab("Latitude") +  scale_fill_viridis() + theme_bw() 
p2 <- p2 + geom_polygon(colour="white", aes(fill=median_loss)) + ggtitle("Median Loss by State") 
ggplotly(p2)

plot_state_boxplots <- function(type){
  if (type == "state")
    p3 <- ggplot(x_train, aes(x=abb, y=loss, color=division))+geom_boxplot() +xlab("State") 
  else 
    p3 <- ggplot(x_train, aes(x=division, y=loss, color=division))+geom_boxplot() +xlab("Region") 
  p3 <- p3 + ylab("log(loss)") + scale_color_viridis(discrete = T) + theme_bw() +
  theme(axis.text.x=element_text(angle = 90, hjust = 1))
ggplotly(p3)
}

```

Here's the boxplot of `loss` vs `cat112` now with state names and in color. Aggregation to the region level may also make sense.

### State

```{r, echo=FALSE}

plot_state_boxplots("state")

```

### Region

```{r, echo=FALSE}

plot_state_boxplots("division")

```

## What is next?

Finally, some more wild ideas

```{r, echo=FALSE}
x_train_p5 <- x_train[, .(median_cont7=median(cont7), Income=median(Income)), by=.(abb, division)]

p5 <- ggplot(x_train_p5, aes(x=Income, y=median_cont7))+geom_point(aes(color=division)) + geom_smooth(method=lm)
p5 <- p5 +xlab("Income") + ylab("cont7") +  scale_color_viridis(discrete = T) + theme_bw()
ggplotly(p5)
```
