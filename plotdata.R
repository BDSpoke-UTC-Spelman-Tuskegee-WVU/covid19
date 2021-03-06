library(tidyverse)
library(lubridate)
require(maps)
require(viridis)
library(ggthemes)
library(gganimate)
library(gifski)

library(usmap)
states_map <- map_data("state")

data_dir <- "COVID-19/csse_covid_19_data/csse_covid_19_time_series"

state_abbreviations <- c("AL", "AK", "AZ", "KS", "UT", "CO", "CT", 
                         "DE", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "AR", 
                         "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", 
                         "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", 
                         "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", 
                         "CA", "VT", "VA", "WA", "WV", "WI", "WY", "DC")
state_names <- c("Alabama", "Alaska", "Arizona", "Kansas", 
                "Utah", "Colorado", "Connecticut", "Delaware", "Florida", 
                "Georgia", "Hawaii", "Idaho", "Illinois", "Indiana", 
                "Iowa", "Arkansas", "Kentucky", "Louisiana", "Maine", 
                "Maryland", "Massachusetts", "Michigan", "Minnesota", 
                "Mississippi", "Missouri", "Montana", "Nebraska", "Nevada", 
                "New Hampshire", "New Jersey", "New Mexico", "New York", 
                "North Carolina", "North Dakota", "Ohio", 
                "Oklahoma", "Oregon", "Pennsylvania", "Rhode Island", 
                "South Carolina", "South Dakota", "Tennessee", "Texas", 
                "California", "Vermont", "Virginia", "Washington", "West Virginia", 
                "Wisconsin", "Wyoming", "District of Columbia")
names(state_names) <- state_abbreviations
names(state_abbreviations) <- state_names

lag_countries <- c("China","Italy","Spain","US")
lag_days <- c(0, 33, 44, 44)
names(lag_days) <- lag_countries


# load and tidy the data
confirmed <- read_csv(paste0(data_dir, "/time_series_19-covid-Confirmed.csv")) %>%
  pivot_longer(cols=c(-`Province/State`, -`Country/Region`, -Lat, -Long),
               names_to="date",
               values_to="cases") %>%
  rename("country" = `Country/Region`, "state" = `Province/State`) %>%
  mutate(date = as.Date(date, "%m/%d/%y")) %>%
  rename("confirmed" = cases)


deaths <- read_csv(paste0(data_dir, "/time_series_19-covid-Deaths.csv")) %>%
  pivot_longer(cols=c(-`Province/State`, -`Country/Region`, -Lat, -Long),
               names_to="date",
               values_to="cases") %>%
  rename("country" = `Country/Region`, "state" = `Province/State`) %>%
  mutate(date = as.Date(date, "%m/%d/%y")) %>%
  rename("deaths" = cases)


recovered <- read_csv(paste0(data_dir, "/time_series_19-covid-Recovered.csv")) %>%
  pivot_longer(cols=c(-`Province/State`, -`Country/Region`, -Lat, -Long),
               names_to="date",
               values_to="cases") %>%
  rename("country" = `Country/Region`, "state" = `Province/State`) %>%
  mutate(date = as.Date(date, "%m/%d/%y")) %>%
  rename("recovered" = cases)

# join the variables
complete <- confirmed %>%
  left_join(recovered) %>%
  left_join(deaths)

by_region <- complete %>%
  filter(country=="US") %>%
  mutate(state = recode(state,
         "Washington, D.C."="District of Columbia",
         "Virgin Islands, U.S."="US Virgin Islands")) %>%
  group_by(state, date) %>%
  summarize(confirmed=sum(confirmed), recovered=sum(recovered), deaths=sum(deaths))

by_region_current <- by_region %>%
  group_by(state) %>%
  summarize(confirmed=max(confirmed), recovered=max(recovered), deaths=max(deaths))

us_states <- by_region %>%
  ungroup() %>%
  separate(state, into=c("region", "st"), sep=",", fill="left", remove=FALSE) %>%
  mutate(st=state_names[str_trim(st)], region=str_trim(region)) %>%
  mutate(state=if_else(is.na(st), state, st)) %>%
  select(-st)

us_states_current <- us_states %>%
  group_by(state, date) %>%
  summarize(cases=sum(confirmed)) %>%
  filter(date <= cutoff_date) %>%
  arrange(state, date) %>%  
  slice(n())

cutoff_date <- today()
states_map %>%
  left_join(
    us_states_current %>%
    mutate(fips = state_abbreviations[state],
          region = tolower(state)) %>%
    filter(!is.na(region)) %>%
    select(region, cases)
  ) %>%
  ggplot(aes(long, lat, group = group)) +
  geom_polygon(aes(fill = cases), color = "white") +
  scale_fill_viridis_c(option = "C") +
  coord_fixed(1.3) +
  ggtitle(cutoff_date)

by_country <- complete %>%
  group_by(country, date) %>%
  summarize(confirmed=sum(confirmed), recovered=sum(recovered), deaths=sum(deaths))

by_country %>%
  filter(country=="Italy" | country=="US") %>%
  mutate("day" = date - min(date),
         "lag_date" = if_else(country=="Italy", date, date - days(11)),
         "lag_days" = lag_date - min(date)) %>%
  ggplot(aes(x=lag_days, y=confirmed, group=country)) +
  geom_point(aes(color=country)) +
  xlab("Day of pandemic") +
  ylab("Confirmed cases") +
  xlim(20, NA) +
  ggtitle(cutoff_date)

by_country %>%
  filter(country %in% lag_countries) %>%
  mutate("day" = date - min(date),
         "lag_date" = date - lag_days[country],
         "lag_days" = lag_date - min(date)) %>%
  ggplot(aes(x=lag_days, y=confirmed, group=country)) +
  geom_point(aes(color=country)) +
  xlab("Day of pandemic") +
  ylab("Confirmed cases") +
  xlim(0, NA) +
  ylim(0, 30000) +
  ggtitle(cutoff_date)

# focal state
focal_states <- c("New York", "California", "Washington")
us_states %>%
  group_by(state, date) %>%
  summarize(cases=sum(confirmed)) %>%
  filter(date <= cutoff_date, state %in% focal_states) %>%
  arrange(state, date) %>%
  ggplot(aes(x=date, y=cases, group=state)) +
  geom_point(aes(color=state)) +
  geom_line(aes(color=state)) +
  xlab("Day of pandemic") +
  ylab("Confirmed cases") +
#  xlim(0, NA) +
#  ylim(0, 30000) +
  ggtitle(cutoff_date)

bay_area_counties <- c("San Francisco County", "Santa Clara County", "San Mateo", "Marin", "Contra Costa County", "Sonoma County", "Alameda County")
