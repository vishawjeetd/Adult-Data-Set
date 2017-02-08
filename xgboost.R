source("fe.R")
source("helper.R")
source("hyperspace.R")

#x <- randomForest(x_train, y_train)


################################# Iteration 1
res = xgb.cv(xgb_params,
             dtrain,
             nrounds=700,
             nfold=3,
             early_stopping_rounds=15,
             print_every_n = 10,
             verbose=0,
             feval=xg_eval_mae,
             maximize=FALSE)

xgb.viz.cv(res)


# Let's test at both end of the curve (build model in the whole dataset)
gbdt1 = xgb.train(xgb_params, dtrain, 200)
gbdt2 = xgb.train(xgb_params, dtrain, 500)

submission(gbdt1, dtest, "xgb1.csv")
submission(gbdt2, dtest, "xgb2.csv")

### The performance?
#xgb1: 1136.13569
#xgb2: 1125.81219
#lower is better

save(res, gbdt1, gbdt2, file="models.rda")

# Took a lot of time
# Let's reduce the number of folds
# Let's look at train error vs test error
# Also, let's measure the time

################################# Iteration 2

start.time <- Sys.time()

res = xgb.cv(xgb_params,
             dtrain,
             nrounds=50,   # changed
             nfold=2,       # changed
             early_stopping_rounds=15,
             print_every_n = 10,
             verbose= 1,
             feval=xg_eval_mae,
             maximize=FALSE)

end.time <- Sys.time()
gc()

time.taken <- end.time - start.time
time.taken
#Time difference of 8.893826 secs

################################# Iteration 3: Hyperparameter Tuning (Caret)

xgb_model = train(x = data.matrix(x_train), y = y_train,
                  trControl = xgb_param_control, tuneGrid = xgb_param_smallgrid,
                  method = "xgbTree", metric = "xg_eval_mae",
                  maximize=FALSE
)

xgb_model$results

xgb_model$bestTune


submission = fread(SUBMISSION_FILE, colClasses = c("integer", "numeric"))
submission$loss = exp(predict(xgb_model, x_test))
write.csv(submission, "caret_xgb.csv", row.names = FALSE)


################################# Iteration 4: Hyperparameter Tuning (by hand)

set.seed(16)

all.models <- list()


xgb_param_day4 = expand.grid(
  nrounds = c(600),
  eta = c(0.01, 0.05, 0.1),
  max_depth = c(5, 7, 9), 
  subsample = c(0.4, 0.6, 0.8),
  colsample_bytree = c(0.4, 0.6, 0.8),
  gamma = c(0.9, 1),
  min_child_weight = c(2, 4)
)
#Abhishek: row 1:15
#Mithilesh: row 16:20
#Vishwajeet: row 21:40
#Nishant: row 41:45
#Ganesh: row 46:50
#Mohammad: row 51:70
#Soumendra: row 71:100


xgb_param1 = expand.grid(
  nrounds = c(600),
  eta = c(0.01, 0.05, 0.1),
  max_depth = c(7, 9), 
  subsample = c(0.6, 0.8),
  colsample_bytree = c(0.6, 0.8),
  gamma = c(0.9),
  min_child_weight = c(2)
)

xgb_param2 = expand.grid(
  nrounds = c(300),
  eta = c(0.05),
  max_depth = c(7), 
  subsample = c(0.8),
  colsample_bytree = c(0.6),
  gamma = c(0.9),
  min_child_weight = c(2)
)

dat <- datasplit.xgb(x_train, y_train)
train <- dat$dtrain
validation <- dat$dvalidation

start.time <- Sys.time()
#for(i in 20:nrow(xgb_param_day4)) {
for(i in 21:41) {
  params <- list(
    eta = xgb_param_day4[i, "eta"],
    max_depth = xgb_param_day4[i, "max_depth"],
    subsample = xgb_param_day4[i, "subsample"],
    colsample_bytree = xgb_param_day4[i, "colsample_bytree"],
    gamma = xgb_param_day4[i, "gamma"],
    min_child_weight = xgb_param_day4[i, "min_child_weight"]
  )
  nrounds = xgb_param_day4[i, "nrounds"]
  res = xgb.cv(params,
               dtrain,
               nrounds=nrounds,   # changed
               nfold=3,           # changed
               early_stopping_rounds=15,
               print_every_n = 10,
               verbose= 1,
               feval=xg_eval_mae,
               maximize=FALSE)
  all.models[[i]] <- res
}
stop.time <- Sys.time()

dur <- stop.time - start.time
dur

save(all.models, xgb_param_day4, dtrain,file="xgb_handtuning.rda")

####

xgb.viz.cv(all.models[[20]])
xgb.viz.cv(all.models[[21]])
xgb.viz.cv(all.models[[22]])
xgb.viz.cv(all.models[[23]])
xgb.viz.cv(all.models[[24]])
y <- all.models[[1]]
names(all.models)

mod1 <- all.models[[24]]
predict(mod1, dvalidation)

xgb_param_day4[20, ]
params1 = list(eta=0.05, max_depth=7, subsample=0.8, 
               colsample_bytree=0.8, gamma=0.9,
               min_child_weight=2)
mod1 = xgb.train(params1, dtrain, 300)

xgb_param_day4[24, ]
params2 = list(eta=0.1, max_depth=9, subsample=0.8, 
               colsample_bytree=0.8, gamma=0.9,
               min_child_weight=2)
mod2 = xgb.train(params2, dtrain, 300)

pred1 = exp(predict(mod1, dvalidation))
pred2 = exp(predict(mod2, dvalidation))

sum(abs(pred1-y_validationSet))/length(pred1)
sum(abs(pred2-y_validationSet))/length(pred2)

idx = dat$idx
validationSet <- x_train[idx==2, ]
y_validationSet <- y_train[idx==2]
dvalidation = xgb.DMatrix(as.matrix(validationSet), label=y_validationSet)

