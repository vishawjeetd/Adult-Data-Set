source("data.R")


ntrain = nrow(train)
train_test = rbind(train, test)
features = names(train)

for (f in features) {
  if (class(train_test[[f]])=="character") {
    #cat("VARIABLE : ",f,"\n")
    levels <- unique(train_test[[f]])
    train_test[[f]] <- as.integer(factor(train_test[[f]], levels=levels))
  }
}
x_train = train_test[1:ntrain, ]
x_test = train_test[(ntrain+1):nrow(train_test), ]

dtrain = xgb.DMatrix(as.matrix(x_train), label=y_train)
dtest = xgb.DMatrix(as.matrix(x_test))

save(x_train, x_test, y_train, file="./intermediate/modelReadyData_generic.rda")
save(dtrain, dtest, file="./intermediate/modelReadyData_xgboost.rda")
print("Feature Engineering complete.")

