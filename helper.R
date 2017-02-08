xg_eval_mae <- function (yhat, dtrain) {
  y = getinfo(dtrain, "label")
  err= mae(exp(y),exp(yhat) )
  return (list(metric = "error", value = err))
}

xgb.viz.cv <- function(dataset) {
  dataset$iteration <- as.integer(rownames(dataset))
  p <- ggplot(dataset, aes(x = iteration)) + 
    geom_line(aes(y = train.error.mean), colour="blue") + 
    geom_line(aes(y = test.error.mean), colour = "red") + 
    #geom_line(aes(y = train.error.mean + train.error.std), colour="black") +
    #geom_line(aes(y = train.error.mean - train.error.std), colour="black") +
    ylab(label="Error (MAE)") + 
    xlab("Iteration") + 
    ggtitle("Test vs Train") +
    scale_colour_manual(name="Dataset", values=c(test="red", train="blue")) 
  return(p)
}

submission <- function(pred_obj, test_dataset, output_fname, path_sample=SUBMISSION_FILE) {
  submission = fread(path_sample, colClasses = c("integer", "numeric"))
  submission$loss = exp(predict(pred_obj, test_dataset))
  write.csv(submission, output_fname, row.names = FALSE)
}

datasplit <- function(data, p=0.7){
  idx <- sample(2, nrow(data), replace=TRUE, prob = c(p, 1-p))
  trainSet <- data[idx==1, ]
  validationSet <- data[idx==2, ]
  return(list(train=trainSet, validation=validationSet, idx=idx))
}


datasplit.xgb <- function(x_train, y_train, p=0.7){
  idx <- sample(2, nrow(x_train), replace=TRUE, prob = c(p, 1-p))
  
  trainSet <- x_train[idx==1, ]
  validationSet <- x_train[idx==2, ]
  
  y_trainSet <- y_train[idx==1]
  y_validationSet <- y_train[idx==2]
  
  dtrain = xgb.DMatrix(as.matrix(trainSet), label=y_trainSet)
  dvalidation = xgb.DMatrix(as.matrix(validationSet), label=y_validationSet)
  
  return(list(train=dtrain, validation=dvalidation, idx=idx))
}

