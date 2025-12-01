

#OHTN exam______________________

library(lme4)
library(lmerTest)
library(ggplot2)
library(dplyr)  

setwd("C:/Maj/Work/Ontario HIV Treatment Network/OHTN_exam/data")
dd <- read.csv("Cohort6.csv", header=TRUE)

# Fit the mixed-effects model (assuming viral suppression as binary outcome)
model <- glmer(viral_suppression ~ time + (1 | ID) + 
                      ART_Adherence_percent + 
                      Housing_Stability + 
                      HIV_Stigma_Score, 
               family = binomial(link = "logit"), 
               data = dd,
               control = glmerControl(optimizer = "bobyqa", 
                         optCtrl = list(maxfun = 100000)))

summary(model)

Fixed effects:
                            Estimate Std. Error z value Pr(>|z|)
(Intercept)                2.663e+03  4.195e+09       0        1
time                      -1.226e-01  6.447e+05       0        1
ART_Adherence_percent     -1.971e+01  3.064e+07       0        1
Housing_StabilityUnstable  5.034e+01  1.109e+08       0        1
HIV_Stigma_Score          -3.907e+01  5.711e+07       0        1


# Alternatively, continuous viral_load:
model2 <- lmer(scale(Viral_Load) ~ time + (1 | ID) + 
                      ART_Adherence_percent + 
                      Housing_Stability + 
                      HIV_Stigma_Score,  
               data = dd,
               control = lmerControl(optimizer = "bobyqa", 
                                     optCtrl = list(maxfun = 100000)))
model_summary <- summary(model2)
fixed_effects <- model_summary$coefficients
z_value <- 1.96  # For 95% confidence interval
conf_intervals_manual <- data.frame(
  Estimate = fixed_effects[, "Estimate"],
  LowerCI = fixed_effects[, "Estimate"] - z_value * fixed_effects[, "Std. Error"],
  UpperCI = fixed_effects[, "Estimate"] + z_value * fixed_effects[, "Std. Error"]
)
conf_intervals_manual[3:5,]

                            Estimate    LowerCI    UpperCI
ART_Adherence_percent     -0.3602782 -0.5563916 -0.1641647
Housing_StabilityUnstable -2.2869121 -3.4457161 -1.1281081
HIV_Stigma_Score          -0.5213792 -0.8162451 -0.2265134


#Plotting ART adherence vs. viral suppression
last_points <- dd %>%
  group_by(ID) %>%
  slice_max(order_by = ART_Adherence_percent, n = 1)  # Last observation by ART_Adherence_percent

# Create the plot with ID labels at the last point for each ID
ggplot(dd, aes(x = ART_Adherence_percent, y = Viral_Load, color = factor(ID))) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  geom_text(data = last_points, aes(label = ID), vjust = -0.5, hjust = -0.5, size = 3) +  # Label the last point of each ID
  theme_minimal() +
  labs(x = "ART Adherence percent", y = "Viral Load") +
  theme(legend.position = "none")


