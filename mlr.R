library(mlr)
library(xgboost)
library(data.table)
library(parallelMap)

set.seed(123)
# create xgboost parameter set with default values and boundaries
xgboost.ps = makeParamSet(
  makeDiscreteLearnerParam(id = "booster", default = "gbtree", values = c("gbtree", "gblinear", "dart")),
  makeDiscreteLearnerParam(id = "tree_method", default = "approx", values = c("auto", "exact", "approx")),
  makeNumericLearnerParam(id = "eta", default = 0.3, lower = 0, upper = 1),
  makeNumericLearnerParam(id = "gamma", default = 0, lower = 0),
  makeIntegerLearnerParam(id = "max_depth", default = 6L, lower = 1L),
  makeNumericLearnerParam(id = "min_child_weight", default = 1, lower = 0),
  makeNumericLearnerParam(id = "subsample", default = 1, lower = 0, upper = 1),
  makeNumericLearnerParam(id = "colsample_bytree", default = 1, lower = 0, upper = 1),
  makeNumericLearnerParam(id = "colsample_bylevel", default = 1, lower = 0, upper = 1),
  makeIntegerLearnerParam(id = "num_parallel_tree", default = 1L, lower = 1L),
  makeNumericLearnerParam(id = "lambda", default = 0, lower = 0),
  makeNumericLearnerParam(id = "lambda_bias", default = 0, lower = 0),
  makeNumericLearnerParam(id = "alpha", default = 0, lower = 0),
  makeUntypedLearnerParam(id = "objective", default = "reg:linear", tunable = FALSE),
  makeUntypedLearnerParam(id = "eval_metric", default = "rmse", tunable = FALSE),
  makeNumericLearnerParam(id = "base_score", default = 0.5, tunable = FALSE),
  makeIntegerLearnerParam(id = "nthread", lower = 1L, tunable = FALSE),
  makeIntegerLearnerParam(id = "nrounds", default = 1L, lower = 1L),
  makeIntegerLearnerParam(id = "silent", default = 0L, lower = 0L, upper = 1L, tunable = FALSE),
  makeIntegerLearnerParam(id = "verbose", default = 1, lower = 0, upper = 2, tunable = FALSE),
  makeIntegerLearnerParam(id = "print_every_n", default = 1L, lower = 1L, tunable = FALSE, requires = quote(verbose == 1L)),
  makeIntegerLearnerParam(id = "early_stop_round", default = NULL, lower = 1L, special.vals = list(NULL)),
  makeDiscreteLearnerParam(id = "normalize_type", default = "tree", values = c("tree", "forest"), requires = quote(booster == "dart")),
  makeNumericLearnerParam(id = "rate_drop", default = 0, lower = 0, upper = 1, requires = quote(booster == "dart")),
  makeNumericLearnerParam(id = "skip_drop", default = 0, lower = 0, upper = 1, requires = quote(booster == "dart"))
)
# create xgboost learner for mlr package
makeRLearner.regr.xgboost.latest = function() {
  makeRLearnerRegr(
    cl = "regr.xgboost.latest",
    package = "xgboost",
    par.set = xgboost.ps,
    par.vals = list(nrounds = 400L, silent = 0L, verbose = 1L, print_every_n = 50),
    properties = c("numerics", "factors", "weights"),
    name = "eXtreme Gradient Boosting",
    short.name = "xgboost"
  )
}
# create xgboost train and predict methods for mlr package
trainLearner.regr.xgboost.latest = function(.learner, .task, .subset, .weights = NULL,  ...) {
  data = getTaskData(.task, .subset, target.extra = TRUE)
  xgboost::xgboost(data = data.matrix(data$data), label = data$target, ...)
}
predictLearner.regr.xgboost.latest = function(.learner, .model, .newdata, ...) {
  m = .model$learner.model
  xgboost:::predict.xgb.Booster(m, newdata = data.matrix(.newdata), ...)
}
# create mlr measure for log-transformed target
mae.log = mae
mae.log$fun = function (task, model, pred, feats, extra.args) {
  measureMAE(exp(pred$data$truth), exp(pred$data$response))
}

# load data
train = fread("../input/train.csv")
test = fread("../input/test.csv")

# remove id
train[, id := NULL]
test[, id := NULL]

# transform target variable and factor variables
train$loss = log(train$loss)
test$loss = -99
char.feat = vlapply(train, is.character)
char.feat = names(char.feat)[char.feat]
for (f in char.feat) {
  levels = unique(c(train[[f]], test[[f]]))
  train[[f]] = as.integer(factor(train[[f]], levels = levels))
  test[[f]] = as.integer(factor(test[[f]], levels = levels))
}

# create mlr train and test task
trainTask = makeRegrTask(data = as.data.frame(train), target = "loss")
testTask = makeRegrTask(data = as.data.frame(test), target = "loss")

# specify mlr learner
lrn = makeLearner("regr.xgboost.latest", nthread = 2, base_score = mean(train$loss))

## This is how you can do hyperparameter tuning with random search
# 1) Define the set of parameters you want to tune
ps = makeParamSet(
  makeIntegerParam("max_depth", lower = 7, upper = 10),
  makeIntegerParam("min_child_weight", lower = 0, upper = 3),
  makeNumericParam("eta", lower = 0.02, upper = 0.08),
  makeNumericParam("colsample_bytree", lower = 3, upper = 5, trafo = function(x) x/5),
  makeNumericParam("subsample", lower = 3, upper = 5, trafo = function(x) x/5)
)

# 2) Use 3-fold Cross-Validation to measure improvements
rdesc = makeResampleDesc("CV", iters = 3L)

# 3) Here we use Random Search (with 45 Iterations) to find the optimal hyperparameter
ctrl =  makeTuneControlRandom(maxit = 45)

# 4) now use the learner on the training Task with the 3-fold CV to optimize your set of parameters in parallel
#parallelStartSocket(15, logging = TRUE)
#parallelExport("mae.log", "makeRLearner.regr.xgboost.latest", "predictLearner.regr.xgboost.latest", "trainLearner.regr.xgboost.latest")
#res = tuneParams(lrn, task = trainTask, resampling = rdesc, par.set = ps, control = ctrl, measures = mae.log)
#parallelStop()
#res
# Tune result:
# Op. pars: max_depth=7; min_child_weight=3; eta=0.0443; colsample_bytree=0.619; subsample=0.798
# mae.test.mean=1.15e+03

# 5) the result of the random search from above is, we fit this model now
set.seed(1)
lrn = setHyperPars(lrn, max_depth=7, min_child_weight=3, eta=0.0443, colsample_bytree=0.619, subsample=0.798, nthread = 16)
mod = train(lrn, trainTask)

# 6) make prediction and submission
pred = getPredictionResponse(predict(mod, testTask))
submission = fread("../input/sample_submission.csv", colClasses = c("integer", "numeric"))
submission$loss = exp(pred)
write.csv(submission, "mlr_hyperopt_starter.csv", row.names = FALSE)
