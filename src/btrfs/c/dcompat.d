/*
 * Copyright (C) 2020 Vladimir Panteleev <d-btrfs@cy.md>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License v2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 021110-1307, USA.
 */

/// Some helper definitions for the D port of other modules.
module btrfs.c.dcompat;

import core.stdc.config;

alias c_int = int;

enum NULL = null;

package enum typesafe = true; // Use D frills

enum __SIZEOF_LONG__ = c_long.sizeof;
