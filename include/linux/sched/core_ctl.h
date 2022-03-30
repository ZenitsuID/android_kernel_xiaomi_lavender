/*
 * Copyright (c) 2016, 2019, The Linux Foundation. All rights reserved.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 and
 * only version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */

#ifndef __CORE_CTL_H
#define __CORE_CTL_H

#define MAX_CPUS_PER_CLUSTER 6
#define MAX_CLUSTERS 3

struct core_ctl_notif_data {
	unsigned int nr_big;
	unsigned int coloc_load_pct;
	unsigned int ta_util_pct[MAX_CLUSTERS];
	unsigned int cur_cap_pct[MAX_CLUSTERS];
};

#ifdef CONFIG_SCHED_CORE_CTL
void core_ctl_check(u64 wallclock);
int core_ctl_set_boost(bool boost);
#else
static inline void core_ctl_check(u64 wallclock) {}
static inline int core_ctl_set_boost(bool boost)
{
	return 0;
}
#endif
#endif