# some default grids to be tried at the beginning of hyperparameter tuning

### Single Model (not caret)
xgb_params = list(
  colsample_bytree = 0.7,
  subsample = 0.7,
  eta = 0.075,
  objective = 'reg:linear',
  max_depth = 6,
  num_parallel_tree = 1,
  min_child_weight = 1,
  base_score = 7
)


### Standard xgboost control (caret)
# Control ((hyper)parameters constant across models)
xgb_param_control = trainControl(
  method = "cv",
  number = 3,
  verboseIter = TRUE,
  returnData = FALSE,
  returnResamp = "all",  # save losses across all models
  #classProbs = TRUE,     # set to TRUE for AUC to be computed
  #summaryFunction = twoClassSummary,
  allowParallel = TRUE
)

### Grid Search starter config
# Grid (parameters varying across models)
xgb_param_startergrid = expand.grid(
  nrounds = c(100, 500, 1000, 2000),
  eta = c(0.001, 0.01, 0.1, 0.2),
  max_depth = c(2, 4, 8, 16), 
  #subsample = c(0.4, 0.5, 0.6, 0.7, 0.8, 0.9),
  colsample_bytree = c(0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9),
  gamma = 1,
  min_child_weight = c(1, 2)
)

# Small Grid (for benchmarking)
xgb_param_smallgrid = expand.grid(
  nrounds = c(100),
  eta = c(0.01),
  max_depth = c(8), 
  subsample = c(0.4, 0.5, 0.6, 0.7, 0.8, 0.9),
  colsample_bytree = c(0.7),
  gamma = 1,
  min_child_weight = c(1, 2)
)
