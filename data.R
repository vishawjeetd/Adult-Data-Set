source("library.R")

ID = 'id'
TARGET = 'loss'
SEED = 0

TRAIN_FILE = "./data/train.csv"
TEST_FILE = "./data/test.csv"
SUBMISSION_FILE = "./data/sample_submission.csv"

train = fread(TRAIN_FILE, showProgress = TRUE)
test = fread(TEST_FILE, showProgress = TRUE)

y_train = log(train[ , TARGET, with = FALSE])[[TARGET]]

train[, c(ID, TARGET) := NULL]
test[, c(ID) := NULL]

save(train, test, file="./intermediate/rawdata.rda")
print("Loading datasets complete.")
